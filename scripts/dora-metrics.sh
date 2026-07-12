#!/usr/bin/env bash
# dora-metrics.sh — DORA-метрики + метрика автономии из живых источников репозитория.
#
# Источники — локальные + опциональный best-effort опрос тикет-бэкенда с graceful-деградацией
# (инвариант «никаких внешних систем» смягчён ОСОЗНАННО — spec 002 G3, FR-10):
#   git log                — commits total / agent-commits (Co-Authored-By) → автономия по коммитам
#   specs/*/audit.md       — init → quality-verdict (lead time); user-approval approved/revise
#   docs/ops-journal.md    — deploy:done|failed (частота деплоев, CFR), incident:open|resolved (MTTR)
#   gh issue list          — ticket-flow (lead time тикетов, open count, доля агентных);
#                            сбой/нет gh/нет сети → «нет данных», exit 0, остальные метрики целы
#
# Метрики: Deployment Frequency · Lead Time (медиана init→PASS) · Change Failure Rate
#          (канон Accelerate: deploy:failed / (deploy:done + deploy:failed) — доля неуспешных
#          попыток от всех; инциденты окна аннотируются рядом, но не входят в формулу —
#          журнал не атрибутирует incident к конкретному деплою) · MTTR (медиана open→resolved) ·
#          Autonomy % (агентные коммиты / все; цель ≥ AUTONOMY_TARGET, по умолчанию 40) ·
#          Ticket flow (spec 002 G3: медиана created→closed, открытые, доля агентных по [Имя])
#
# Usage: bash scripts/dora-metrics.sh [repo-root] [--days N] [--html] [--tickets-file <json>]
#   --html — HTML-фрагмент для встраивания в Flight Deck (pipeline-dashboard.sh)
#   --tickets-file — офлайн-подмена fetch'а тикетов JSON-файлом (детерминированные тесты, FR-13)
# ENV autonomy v2 (spec 006, все advisory):
#   RUN_TOKEN_BUDGET=<int> — бюджет токенов прогона (FR-6); 0/нечисловой = не задан (guard)
#   NONTRIVIAL_LOC=<int>   — порог LoC advisory-флага прямых фиксов (FR-20); дефолт 50 (Iron Rule 2)
#   TICKET_COMMIT_RE=<re>  — perl-регекс тикет-ссылок в commit message (FR-16); дефолт покрывает
#                            Closes/Fixes/Refs #N и KEY-N; регекс печатается в строке вывода (NFR-6)
# Exit: 0 (метрики advisory — coverage-цель с честным отчётом, не гейт)
set -uo pipefail

ROOT="."; DAYS=30; MODE="text"; TICKETS_FILE=""
while [ $# -gt 0 ]; do
  case "$1" in
    --days) DAYS="${2:?}"; shift 2;;
    --html) MODE="html"; shift;;
    --tickets-file) TICKETS_FILE="${2:?}"; shift 2;;
    *) ROOT="$1"; shift;;
  esac
done
cd "$ROOT" 2>/dev/null || { echo "dora-metrics: FATAL: нет каталога $ROOT" >&2; exit 2; }
TARGET="${AUTONOMY_TARGET:-40}"

# --- git: автономия по коммитам за окно ---
C_TOTAL=0; C_AGENT=0
if git rev-parse --git-dir >/dev/null 2>&1; then
  C_TOTAL="$(git log --since="$DAYS days ago" --pretty=%H 2>/dev/null | wc -l | tr -d ' ')"
  C_AGENT="$(git log --since="$DAYS days ago" --grep='Co-Authored-By' --pretty=%H 2>/dev/null | wc -l | tr -d ' ')"
fi

# --- autonomy v2 (spec 006, P-6/D-7): ЕДИНЫЙ git log с датами и полным message за прогон ---
# Общий источник ISO-недельных трендов (FR-7) и тикет-ссылок коммитов (FR-16/FR-18в):
# per-неделя/per-тикет git-вызовы запрещены (D-1/D-2). Файл — вне git-дерева, уборка trap'ом.
V2TMP="$(mktemp -d "${TMPDIR:-/tmp}/dora-v2.XXXXXX")"
trap 'rm -rf "$V2TMP"' EXIT
if git rev-parse --git-dir >/dev/null 2>&1; then
  git log --since="$DAYS days ago" --pretty=format:'%x1e%H|%at|%B' >"$V2TMP/commits" 2>/dev/null
  # FR-20 (D-2): ровно ОДИН numstat-вызов за прогон, по окну; фильтрация по SHA дорожки — in-perl
  git log --since="$DAYS days ago" --pretty=format:'%x1e%H' --numstat >"$V2TMP/numstat" 2>/dev/null
fi
# FR-18б (D-1): ОДИН grep-проход маркеров «Источник: тикет KEY» по specs/*/spec.md
# (маркер spec 002 FR-18; KEY_RE — как в spec-lint.sh: BOARD-52 / #123)
grep -h -E '^[-*>]?[[:space:]]*Источник:.*[Тт]икет' specs/*/spec.md 2>/dev/null \
  | grep -oE '([A-Za-z][A-Za-z0-9_]*-[0-9]+|#[0-9]+)' >"$V2TMP/speckit-keys" || true

# --- журналы: собираем строки таблиц (audit per spec + ops-journal) и считаем в perl ---
AUDITS=()
for a in specs/*/audit.md; do [ -f "$a" ] && AUDITS+=("$a"); done
OPS="docs/ops-journal.md"

# --- ticket flow (spec 002 G3, FR-5..13): fetch тикетов В BASH-СЛОЕ, до perl (FR-10) ---
# Контракт advisory: любой сбой источника → «нет данных», exit 0, остальные метрики не задеты (NFR-2).
#   --tickets-file <json> полностью подменяет живой fetch (FR-13, офлайн-тесты);
#   иначе gh issue list --state all --limit 500 (ровно ≥500 строк → пометка approximate, FR-6);
#   TTL-кэш: ${TMPDIR:-/tmp}/dora-tickets-<cksum repo-root>.json, 15 мин по mtime (FR-12) —
#   вне git-дерева by construction; в кэше только payload тикетов, НИКОГДА токены/заголовки;
#   протухший кэш при провале refetch НЕ используется (честное «нет данных» вместо тихой тухлятины);
#   ISSUE_BACKEND=tracker (ENV или team.params корня) → провенанс «github-зеркало» (FR-6);
#   timeout fetch ≤10 с — perl alarm + exec (без GNU timeout, переносимо bash 3.2 / macOS).
T_JSON=""; T_SRC=""; T_NODATA="нет данных (gh недоступен)"
if [ -n "$TICKETS_FILE" ]; then
  if [ -f "$TICKETS_FILE" ]; then T_JSON="$TICKETS_FILE"; T_SRC="file (--tickets-file)"
  else T_NODATA="нет данных (нет файла: $TICKETS_FILE)"; fi
elif command -v gh >/dev/null 2>&1 && git rev-parse --git-dir >/dev/null 2>&1; then
  IB="${ISSUE_BACKEND:-}"
  [ -n "$IB" ] || IB="$(sed -n 's/^ISSUE_BACKEND="\([^"]*\)".*$/\1/p' team.params 2>/dev/null | head -1)"
  T_CACHE="${TMPDIR:-/tmp}/dora-tickets-$(pwd -P | cksum | awk '{print $1}').json"
  t_fresh=0
  if [ -f "$T_CACHE" ] && perl -e 'exit(time - (stat($ARGV[0]))[9] < 900 ? 0 : 1)' "$T_CACHE" 2>/dev/null; then
    t_fresh=1
  elif perl -e 'alarm shift; exec @ARGV' 10 gh issue list --state all --limit 500 \
         --json number,createdAt,closedAt,title >"$T_CACHE.tmp.$$" 2>/dev/null; then
    mv "$T_CACHE.tmp.$$" "$T_CACHE"; t_fresh=1
  else
    rm -f "$T_CACHE.tmp.$$"
  fi
  if [ "$t_fresh" -eq 1 ]; then
    T_JSON="$T_CACHE"
    if [ "$IB" = "tracker" ]; then T_SRC="github-зеркало (источник истины — трекер; лаг синка ~20 мин)"
    else T_SRC="github"; fi
  fi
fi
# Список агентских имён для доли агентных тикетов (FR-9): константа ростера из XTRACKER_FILING.md
# (НЕ generic \[\w+\] — иначе ложно ловит [bug]); переопределяется ENV TICKET_AGENT_NAMES.
T_ROSTER="${TICKET_AGENT_NAMES:-Her,Semiglazka,Zemlemer,Renata,Kulibin,Zanuda}"

C_TOTAL="$C_TOTAL" C_AGENT="$C_AGENT" DAYS="$DAYS" MODE="$MODE" TARGET="$TARGET" OPS_J="$([ -f "$OPS" ] && echo "$OPS")" \
T_JSON="$T_JSON" T_SRC="$T_SRC" T_NODATA="$T_NODATA" T_ROSTER="$T_ROSTER" \
RUN_TOKEN_BUDGET="${RUN_TOKEN_BUDGET:-}" V2_DIR="$V2TMP" \
NONTRIVIAL_LOC="${NONTRIVIAL_LOC:-}" TICKET_COMMIT_RE="${TICKET_COMMIT_RE:-}" \
EVAL_JSON="$([ -f "$ROOT/tests/agent-evals/last-run.json" ] && echo "$ROOT/tests/agent-evals/last-run.json")" \
perl - "${AUDITS[@]:-}" <<'PERL'
use strict; use warnings; use utf8;
use Time::Local qw(timegm);
binmode STDOUT, ':utf8';

my ($days, $mode, $target) = ($ENV{DAYS}, $ENV{MODE}, $ENV{TARGET});
my ($c_total, $c_agent)    = ($ENV{C_TOTAL} // 0, $ENV{C_AGENT} // 0);
my $now = time; my $cut = $now - $days * 86400;

# autonomy v2 (spec 006) — пороги-константы (Known Risk 5: экспертные, каждый печатается в своей
# строке вывода — NFR-6 «панель без порога лжёт молча»; пересмотр — по накопленной истории)
my $TREND_MIN = 3;   # FR-7/Д-4: минимум непустых ISO-недель для рендера тренда
my $XCHK_K  = 5;     # FR-17: минимум прогонов с гейтом для cross-check осей
my $XCHK_M  = 20;    # FR-17: минимум коммитов окна для cross-check осей
my $XCHK_PP = 25;    # FR-17: порог расхождения осей, процентные пункты

sub ts2e { my $t = shift // ''; return $t =~ /^(\d{4})-(\d{2})-(\d{2})T(\d{2}):(\d{2}):(\d{2})Z/ ? eval { timegm($6,$5,$4,$3,$2-1,$1) } : undef }
sub rows { my $f = shift; my @r;
  open(my $h, '<:utf8', $f) or return @r;
  while (<$h>) { chomp;
    next unless /^\| (.*?) \| (.*?) \| (.*?) \|$/;
    my ($ts,$ev,$det) = ($1,$2,$3);
    next if $ts eq 'ts (UTC)' || $ts =~ /^-+$/;
    my $e = ts2e($ts); next unless defined $e;
    push @r, [$e,$ev,$det];
  } @r }
sub median { my @s = sort { $a <=> $b } @_; return undef unless @s; return $s[$#s/2] }
sub hdur { my $s = shift; return 'n/a' unless defined $s;
  return $s < 3600 ? sprintf('%dm', $s/60) : $s < 86400 ? sprintf('%.1fh', $s/3600) : sprintf('%.1fd', $s/86400) }
# локальная копия scripts/lib/deck-lib.pl::esc (spec 006 D-6/ARCH-3: dora-metrics автономен,
# зависимость от lib дашбордов не вводится; дрейф-риск принят как ничтожный — esc стабилен,
# правки только синхронно там и тут). Через esc() идёт ЛЮБОЕ не-числовое внешнее значение в --html.
sub esc { my $s = shift // ''; $s =~ s/&/&amp;/g; $s =~ s/</&lt;/g; $s =~ s/>/&gt;/g; $s }
# ISO-8601 неделя (UTC) из epoch → 'YYYY-Wnn' (FR-7): чистая арифметика вместо POSIX::strftime %V
# (%V/%G делегируются libc — непереносимо); алгоритм канонический: w = (yday - dow + 10) / 7
sub isoweek { my $e = shift; my @t = gmtime($e);
  my ($y, $yd, $dow) = ($t[5] + 1900, $t[7] + 1, $t[6] == 0 ? 7 : $t[6]);
  my $p = sub { my $x = shift; ($x + int($x/4) - int($x/100) + int($x/400)) % 7 };
  my $wk_in = sub { my $yy = shift; 52 + ($p->($yy) == 4 || $p->($yy - 1) == 3 ? 1 : 0) };
  my $w = int(($yd - $dow + 10) / 7);
  if    ($w < 1)            { $y--; $w = $wk_in->($y) }
  elsif ($w > $wk_in->($y)) { $y++; $w = 1 }
  sprintf('%04d-W%02d', $y, $w) }
sub v2_trend { # \%{ISO-неделя → значение} → компактная строка либо undef при < $min непустых бакетов
  my ($h, $min) = @_;
  my @w = sort keys %$h;
  return undef if @w < $min;
  return join(' · ', map { my $l = $_; $l =~ s/^\d{4}-//; "$l $h->{$_}" } @w) }

# lead time + revise по прогонам пайплайна
my (@lead, $appr, $rev); $appr = $rev = 0;
# autonomy v2 (spec 006 FR-1/2/3/5/12): агрегаты ПО ПРОГОНАМ; «активность» прогона в окне — только
# по user-approval/init/usage:*/ticket:linked (осиротевшие agent:*:start не влияют by construction)
my ($v2_act, $v2_ucov, $v2_usum, @v2_umed, %v2_usrc) = (0, 0, 0);
my ($v2_k, $v2_rev, $v2_ab, $v2_asis, $v2_iman) = (0, 0, 0, 0, 0);
my ($v2_kt, $v2_revt, $v2_asist) = (0, 0, 0);   # FR-15: срез по тикет-связанным прогонам
my (%wk_init, %wk_rev);
my %linked_keys;   # FR-18а: KEY-и из ticket:linked всех audit.md (hash-set одного прохода, D-1)
for my $f (grep { length } @ARGV) {
  my @r = rows($f);
  my ($init) = map { $_->[0] } grep { $_->[1] eq 'init' } @r;
  my ($pass) = map { $_->[0] } grep { $_->[1] eq 'quality-verdict' && $_->[2] =~ /^PASS/ } @r;
  push @lead, $pass - $init if defined $init && defined $pass && $pass >= $cut;
  for (@r) { next unless $_->[0] >= $cut && $_->[1] eq 'user-approval';
    $appr++ if $_->[2] =~ /^approved/; $rev++ if $_->[2] =~ /^revise/; }
  # autonomy v2: per-run флаги отдельным аддитивным проходом (существующий счёт выше не тронут)
  my ($run_act, $run_us, $run_uok, $g_any, $g_rev, $g_ab, $run_t) = (0, 0, 0, 0, 0, 0, 0);
  for (@r) {
    my ($e, $ev, $det) = @$_;
    if ($ev eq 'ticket:linked') {   # связь исторична: флаг и KEY-и считаются и ВНЕ окна (FR-15/FR-18а);
      $run_t = 1;                   # detail — «KEY» либо «OLD → NEW» (перепривязка: оба KEY в set)
      for my $k (split /\s*\x{2192}\s*/, ($det // '')) {
        $k =~ s/^\s+|\s+$//g; $linked_keys{$k} = 1 if length $k;
      }
    }
    next unless $e >= $cut;
    if ($ev eq 'user-approval') {
      $run_act = 1; $g_any++;
      if    (($det // '') =~ /^revise/) { $g_rev++; eval { $wk_rev{isoweek($e)}++; 1 } }
      elsif (($det // '') =~ /^abort/)  { $g_ab++ }
    }
    elsif ($ev eq 'init')                { $run_act = 1; eval { $wk_init{isoweek($e)}++; 1 } }
    elsif ($ev eq 'ticket:linked')       { $run_act = 1 }
    elsif ($ev eq 'intervention:manual') { $run_act = 1; $v2_iman++ }
    elsif ($ev =~ /^usage:/) {
      $run_act = 1;
      # D-3 (SEC-3, I-13/I-16): событие засчитывается ТОЛЬКО при tokens=<int> И непустом source=;
      # иначе непарсибельно — пропуск без падения (FR-5); eval — изоляция парсера (P-8/NFR-3)
      my $tok = eval {
        my ($t) = ($det // '') =~ /\btokens=(\d+)(?:\s|$)/;
        my ($s) = ($det // '') =~ /\bsource=(\S+)/;
        (defined $t && defined $s && length $s) ? do { $v2_usrc{$s} = 1; $t } : undef;
      };
      if (defined $tok) { $run_us += $tok; $run_uok = 1 }
    }
  }
  if ($run_act) {
    $v2_act++;
    if ($run_uok) { $v2_ucov++; $v2_usum += $run_us; push @v2_umed, $run_us }
  }
  # FR-1/FR-2: прогон = одна единица независимо от числа событий; abort ≠ revise (Edge Cases)
  if ($g_any) {
    $v2_k++;
    $v2_rev++  if $g_rev;
    $v2_ab++   if $g_ab;
    $v2_asis++ if !$g_rev && !$g_ab;
    if ($run_t) { $v2_kt++; $v2_revt++ if $g_rev; $v2_asist++ if !$g_rev && !$g_ab }
  }
}

# ── autonomy v2: разбор единого git-источника (SHA|epoch|message) — недели + Co-Authored-By;
#    U-3 доиспользует ЭТОТ ЖЕ проход для тикет-ссылок (FR-16/FR-18в) — второго git-вызова нет ──
my $v2dir = $ENV{V2_DIR} // '';
my ($v2_ct, $v2_ca, $v2_cref) = (0, 0, 0);
my (%wk_ct, %wk_ca, %commit_keys, %sha_agent);
# FR-16: регекс тикет-ссылок — константа с ENV-переопределением; источник печатается (NFR-6/SEC-4)
my $v2_re = $ENV{TICKET_COMMIT_RE} // ''; utf8::decode($v2_re);
my $re_src;
if ($v2_re ne '') { $re_src = "ENV TICKET_COMMIT_RE: $v2_re" }
else { $v2_re = '\b(?:[Cc]loses|[Ff]ixes|[Rr]efs)\s+#(\d+)|\b([A-Z][A-Z0-9]+-\d+)\b';
       $re_src = 'дефолт (Closes/Fixes/Refs #N · KEY-N)' }
my $v2_qr = eval { qr/$v2_re/ };
$re_src .= ' — НЕ КОМПИЛИРУЕТСЯ: тикет-ссылки не считаны (advisory)' unless defined $v2_qr;
if ($v2dir ne '' && -s "$v2dir/commits") {
  eval {  # D-6/P-8: die парсера деградирует только v2-коммит-метрики, не остальной рендер
    open(my $h, '<:utf8', "$v2dir/commits") or die "open: $!";
    local $/; my $raw = <$h>; close $h;
    for my $rec (split /\x1e/, $raw) {
      next unless $rec =~ /^([0-9a-f]{7,40})\|(\d+)\|(.*)$/s;
      my ($sha, $at, $msg) = ($1, $2, $3);
      $v2_ct++;
      my $agent = $msg =~ /Co-Authored-By/ ? 1 : 0;
      if ($agent) { $v2_ca++; $sha_agent{$sha} = 1 }
      eval { my $w = isoweek($at); $wk_ct{$w}++; $wk_ca{$w}++ if $agent; 1 };
      # FR-16/FR-18в: тикет-ссылки из ПОЛНОГО message (Edge Case «ссылка в теле»); map KEY → [SHA]
      if (defined $v2_qr) {
        my $hit = 0;
        while ($msg =~ /$v2_qr/g) {
          my @g = grep { defined $_ && length $_ } ($1, $2, $3, $4, $5, $6, $7, $8, $9);
          my $tok = @g ? $g[0] : $&;
          next unless defined $tok && length $tok;
          $tok = "#$tok" if $tok =~ /^\d+$/;   # нормализация «Closes #N» → ключ '#N'
          push @{$commit_keys{$tok}}, $sha;
          $hit = 1;
        }
        $v2_cref++ if $hit;
      }
    }
    1;
  } or do { ($v2_ct, $v2_ca, $v2_cref) = (0, 0, 0); %wk_ct = (); %wk_ca = (); %commit_keys = (); %sha_agent = (); };
}

# FR-20 (D-2): разбор ЕДИНОГО numstat-файла окна → LoC и корневые каталоги per SHA;
# повреждённые строки (без табуляции, бинарные '-') пропускаются, die изолирован (P-8)
my (%sha_loc, %sha_dirs);
if ($v2dir ne '' && -s "$v2dir/numstat") {
  eval {
    open(my $h, '<:utf8', "$v2dir/numstat") or die "open: $!";
    local $/; my $raw = <$h>; close $h;
    for my $rec (split /\x1e/, $raw) {
      my ($first, @rest) = split /\n/, $rec;
      next unless defined $first && $first =~ /^([0-9a-f]{7,40})/;
      my $sha = $1;
      for (@rest) {
        next unless /^(\d+|-)\t(\d+|-)\t(.+)$/;
        $sha_loc{$sha} += ($1 eq '-' ? 0 : $1) + ($2 eq '-' ? 0 : $2);
        my ($root) = $3 =~ m{^([^\/]+)};
        $sha_dirs{$sha}{$root} = 1 if defined $root;
      }
    }
    1;
  } or do { %sha_loc = (); %sha_dirs = (); };
}

# FR-18б (D-1): hash-set KEY-ов маркеров spec.md — один проход, добыт bash-слоем
my %speckit_keys;
if ($v2dir ne '' && -f "$v2dir/speckit-keys") {
  eval { open(my $h, '<:utf8', "$v2dir/speckit-keys") or die "open: $!";
         while (<$h>) { chomp; $speckit_keys{$_} = 1 if length } close $h; 1 } or %speckit_keys = ();
}

# деплои/инциденты из ops-journal
my ($dep_ok, $dep_fail, $inc_open, @mttr, %open) = (0, 0, 0);
if (my $oj = $ENV{OPS_J}) {
  for my $r (rows($oj)) {
    my ($e, $ev, $det) = @$r;
    my ($slug) = ($det // '') =~ /^(\S+)/;
    if    ($ev eq 'incident:open')     { $open{$slug // ''} = $e; $inc_open++ if $e >= $cut }
    elsif ($ev eq 'incident:resolved') { my $o = delete $open{$slug // ''};
                                         push @mttr, $e - $o if defined $o && $e >= $cut }
    next unless $e >= $cut;
    $dep_ok++   if $ev eq 'deploy:done';
    $dep_fail++ if $ev eq 'deploy:failed';
  }
}

# ticket flow (spec 002 G3): payload уже добыт bash-слоем (FR-10) — здесь только счёт.
# JSON::PP — core-модуль perl (FR-11): без jq/python3, agent-env-audit не расширяется.
my ($tj, $tsrc) = ($ENV{T_JSON} // '', $ENV{T_SRC} // '');
my $t_nodata = $ENV{T_NODATA} // 'нет данных';
# ENV приходит байтами: кириллицу (провенанс/причина) декодируем, иначе :utf8-STDOUT даёт кракозябры
utf8::decode($tsrc); utf8::decode($t_nodata);
my ($t_src_s, $t_lead, $t_open, $t_agent, $t_reopen);
my @v2_closed;   # autonomy v2 (FR-18): [number, title, closedAt] закрытых в окне — для дорожек
if ($tj ne '' && -f $tj) {
  my $tickets = eval {
    require JSON::PP;
    open(my $h, '<:raw', $tj) or die "open: $!";
    local $/; JSON::PP::decode_json(scalar <$h>);
  };
  if (ref $tickets eq 'ARRAY') {
    my @tl; my ($open_n, $created_n, $agent_n) = (0, 0, 0);
    my @names = grep { length } split /\s*,\s*/, ($ENV{T_ROSTER} // '');
    for my $t (@$tickets) {
      my ($c, $cl) = (ts2e($t->{createdAt}), ts2e($t->{closedAt}));
      my $title = $t->{title} // '';
      $open_n++ unless defined $cl;
      push @tl, $cl - $c if defined $c && defined $cl && $cl >= $cut && $cl >= $c;
      push @v2_closed, [$t->{number} // '', $title, $cl] if defined $cl && $cl >= $cut;  # v2 FR-18
      next unless defined $c && $c >= $cut;
      $created_n++;
      # FR-9: подстрока [<Имя>], НЕ якорь на начало — Пристав ставит системный [GH#n] ПЕРЕД [Имя]
      $agent_n++ if grep { index($title, "[$_]") >= 0 } @names;
    }
    # ровно потолок --limit 500 → окно, вероятно, усечено — метка approximate (FR-6, честное усечение)
    my $approx = ($tsrc !~ /^file/ && @$tickets >= 500) ? ' · approximate: окно усечено (--limit 500)' : '';
    $t_src_s = $tsrc . $approx;
    $t_lead  = @tl ? hdur(median(@tl)) . ' (медиана, ' . scalar(@tl) . ' закрытых в окне)' : 'нет закрытых тикетов в окне';
    $t_open  = sprintf('%d', $open_n);
    $t_agent = $created_n ? sprintf('%.0f%% (%d из %d заведённых за окно)', 100 * $agent_n / $created_n, $agent_n, $created_n) : 'нет заведённых за окно';
    # FR-8: история транзишенов не входит в запрошенный набор полей gh issue list — честное n/a
    $t_reopen = 'n/a (gh issue list не отдаёт историю транзишенов; расширение — вне scope 002)';
  } else {
    $t_nodata = 'нет данных (невалидный JSON тикетов)';
  }
}

my $dep_all = $dep_ok + $dep_fail;
my $freq  = $dep_ok ? sprintf('%.1f/нед', $dep_ok / ($days / 7)) : 'нет данных (лог deploy:done в ops-journal)';
my $lead  = @lead ? hdur(median(@lead)) . ' (медиана, ' . scalar(@lead) . ' прогонов)' : 'нет завершённых прогонов';
# CFR по канону Accelerate: доля попыток деплоя, завершившихся сбоем, от ВСЕХ попыток.
# Старая формула ((fail+incidents)/done) давала >100% и 'n/a' при «0 done + N failed»
# (аудит 2026-07-02, рек.2). Инциденты не атрибутируемы к деплою из журнала — аннотация рядом.
my $cfr   = $dep_all
  ? sprintf('%.0f%% (%d fail из %d попыток)%s', 100*$dep_fail/$dep_all, $dep_fail, $dep_all,
            $inc_open ? " · +$inc_open incident(ов) в окне" : '')
  : 'n/a (нет деплоев в окне)';
my $mttr  = @mttr ? hdur(median(@mttr)) . ' (медиана, ' . scalar(@mttr) . ' инцидентов)' : ($inc_open ? "$inc_open открыт(о) без resolve" : 'инцидентов нет');
my $auto  = $c_total ? sprintf('%.0f', 100 * $c_agent / $c_total) : undef;
my $auto_s = defined $auto ? "$auto% ($c_agent из $c_total коммитов)" : 'нет git-истории';
my $auto_ok = defined $auto && $auto >= $target;
my $gates = ($appr + $rev) ? sprintf('%d approved / %d revise', $appr, $rev) : 'нет данных';

# ── autonomy v2 (spec 006): intervention rate / merged-as-is (FR-1/FR-2/FR-3) —
#    NFR-6: каждая строка несёт источник и выборку; FR-12: guard на нулевой знаменатель ──
my $v2_gate_nd = 'нет прогонов с гейтом в окне · источник: specs/*/audit.md user-approval';
my $v2_ir = $v2_k
  ? sprintf('%.0f%% (%d из %d прогонов с гейтом)', 100 * $v2_rev / $v2_k, $v2_rev, $v2_k)
    . ($v2_kt   ? sprintf(' · по тикетным: %.0f%% (%d из %d)', 100 * $v2_revt / $v2_kt, $v2_revt, $v2_kt) : '')
    . ($v2_ab   ? " · (+$v2_ab abort)" : '')
    . ($v2_iman ? " · +$v2_iman задекларированных ручных правок (нижняя граница, self-declared)" : '')
    . ' · источник: specs/*/audit.md user-approval'
  : $v2_gate_nd;
my $v2_ma = $v2_k
  ? sprintf('%.0f%% (%d из %d прогонов с гейтом; все user-approval=approved — по гейтам владельца, не PR)',
            100 * $v2_asis / $v2_k, $v2_asis, $v2_k)
    . ($v2_kt ? sprintf(' · по тикетным: %.0f%% (%d из %d)', 100 * $v2_asist / $v2_kt, $v2_asist, $v2_kt) : '')
    . ' · источник: specs/*/audit.md user-approval'
  : $v2_gate_nd;

# ── autonomy v2: тикет-покрытие прогонов (FR-15) и тикет-ссылки коммитов (FR-16) ──
my $v2_tc = $v2_k
  ? sprintf('%d из %d прогонов с гейтом (событие ticket:linked) · источник: specs/*/audit.md', $v2_kt, $v2_k)
  : 'нет прогонов с гейтом в окне · источник: specs/*/audit.md ticket:linked';
my $v2_cr = $v2_ct
  ? sprintf('%.0f%% (%d из %d коммитов окна) · источник: git log, регекс %s', 100 * $v2_cref / $v2_ct, $v2_cref, $v2_ct, $re_src)
  : 'нет коммитов в окне · источник: git log';
# FR-16: постоянная сноска-легенда ограничений коммит-оси (frozen-строка «Автономия» не меняется, FR-8)
my $v2_fn = 'по коммитам: Co-Authored-By бинарен — интервенции внутри сессии не видны; вес = число коммитов · источник: git log';

# ── autonomy v2 (FR-17): cross-check коммит-оси и гейт-оси — только на достаточной выборке,
#    ниже порогов строка НЕ печатается (Д-4: не шумим на малых данных) ──
my $v2_xchk;
if ($v2_k >= $XCHK_K && $v2_ct >= $XCHK_M && defined $auto) {
  my $ma_pct = 100 * $v2_asis / $v2_k;
  my $d = abs($auto - $ma_pct);
  if ($d > $XCHK_PP) {
    $v2_xchk = sprintf('оси автономии расходятся: коммиты %d%% vs гейты %.0f%% (Δ %.0f п.п. > %d п.п.; пороги выборки K≥%d прогонов, M≥%d коммитов) — интервенции внутри сессий или мелкие коммиты искажают ось · источник: git log + audit.md',
                       $auto, $ma_pct, $d, $XCHK_PP, $XCHK_K, $XCHK_M);
  }
}

# ── autonomy v2 (FR-18/FR-19/FR-20): дорожки закрытых тикетов — one-pass hash-set lookups
#    (D-1: O(S+T+C), закрытие P-4); «первый матч выигрывает» СТРУКТУРОЙ if/elsif (ARCH-6);
#    классификация НЕ материализуется — чистая функция от журналов (I-4) ──
my ($v2_tracks, $v2_tr_a, $v2_tr_b, $v2_tr_c, $v2_fr20);
my $ntl = ($ENV{NONTRIVIAL_LOC} // '') =~ /^([1-9]\d*)$/ ? $1 : 50;  # guard FR-20: 0/нечисловой → дефолт 50
if (defined $t_src_s) {
  my @names2 = grep { length } split /\s*,\s*/, ($ENV{T_ROSTER} // '');
  my %n = (spec => 0, speckit => 0, direct => 0, nocode => 0);
  my (%agent_t, %shas_of, @flag20);
  for my $ct (@v2_closed) {
    my ($num, $title, $cl) = @$ct;
    my @keys = ("#$num");
    push @keys, $1 if $title =~ /\[([A-Za-z][A-Za-z0-9_]*-\d+)\]/;  # KEY-форма зеркала трекера; [bug] не матчится
    my ($tr, @shas);
    if    (grep { $linked_keys{$_} }  @keys) { $tr = 'spec' }
    elsif (grep { $speckit_keys{$_} } @keys) { $tr = 'speckit'; @shas = map { @{$commit_keys{$_} // []} } @keys }
    elsif (@shas = map { @{$commit_keys{$_} // []} } @keys) { $tr = 'direct' }
    else  { $tr = 'nocode' }
    $n{$tr}++;
    $agent_t{$tr}++ if grep { index($title, "[$_]") >= 0 } @names2;   # FR-19: механизм spec 002 FR-9
    my %seen; @shas = grep { !$seen{$_}++ } @shas;
    push @{$shas_of{$tr}}, @shas;
    if ($tr eq 'direct' && @shas) {
      # FR-20: суммарный дифф связанных коммитов из ЕДИНОГО numstat + >1 корневого каталога;
      # рендер — ТОЛЬКО номер/KEY тикета, НИКОГДА title (SEC-2/D-5)
      my ($loc, %dirs) = (0);
      for my $s (@shas) { $loc += $sha_loc{$s} // 0; $dirs{$_} = 1 for keys %{$sha_dirs{$s} // {}} }
      push @flag20, "#$num" if $loc > $ntl || keys %dirs > 1;
    }
  }
  $v2_tracks = sprintf('spec-pipeline %d · speckit %d · прямой фикс %d · без кода %d (из %d закрытых за окно) · источники: audit.md ticket:linked / spec.md «Источник: тикет» / git log',
                       $n{spec}, $n{speckit}, $n{direct}, $n{nocode}, scalar @v2_closed);
  if ($n{spec}) {   # FR-19а: родная гейт-ось — срез FR-15 по тикет-связанным прогонам
    $v2_tr_a = $v2_kt
      ? sprintf('гейт-ось (родная): IR %.0f%% · merged-as-is %.0f%% (по %d тикет-связанным прогонам с гейтом) · источник: audit.md',
                100 * $v2_revt / $v2_kt, 100 * $v2_asist / $v2_kt, $v2_kt)
      : 'нет тикет-связанных прогонов с гейтом в окне · источник: audit.md';
  }
  my $trline = sub {   # FR-19б/в: агентные тикеты + агентные коммиты по ссылкам; гейт-ось честно n/a
    my ($key) = @_;
    return undef unless $n{$key};
    my %seen; my @sh = grep { !$seen{$_}++ } @{$shas_of{$key} // []};
    my $ac = grep { $sha_agent{$_} } @sh;
    my $cpart = @sh ? sprintf('агентных коммитов по ссылкам %d из %d', $ac, scalar @sh)
                    : 'коммитов со ссылкой нет';
    return sprintf('агентных тикетов %d из %d (по [Имя] из T_ROSTER) · %s · гейт-ось: n/a (дорожка без гейта by design) · источник: тикеты + git log',
                   $agent_t{$key} // 0, $n{$key}, $cpart);
  };
  $v2_tr_b = $trline->('speckit');
  $v2_tr_c = $trline->('direct');
  if (@flag20) {
    $v2_fr20 = sprintf('%d прямых фиксов крупнее порога (LoC>%d или >1 корневого каталога) без спеки — проверь Iron Rule 2: %s · источник: git log --numstat окна',
                       scalar @flag20, $ntl, join(', ', @flag20));
  }
} else {
  # тикеты недоступны → «нет данных» (существующий контракт ticket-flow); FR-20-флаг молчит вместе
  # с классификацией — в сводном дашборде флота (gh-заглушка) это ожидаемый периметр (P-7, Edge Cases)
  $v2_tracks = $t_nodata;
}

# ── autonomy v2: weekly trends (FR-7/Д-4): < TREND_MIN непустых ISO-недель → честное «нет данных» ──
my $T_NOTREND = 'нет данных для тренда (< 3 нед. истории)';
my %wk_auto   = map { $_ => sprintf('%.0f%%', 100 * ($wk_ca{$_} // 0) / $wk_ct{$_}) } grep { $wk_ct{$_} } keys %wk_ct;
my %wk_init_d = map { $_ => $wk_init{$_} } grep { $wk_init{$_} } keys %wk_init;
my %wk_rev_d  = map { $_ => $wk_rev{$_} }  grep { $wk_rev{$_} }  keys %wk_rev;
my $v2_t_auto = (v2_trend(\%wk_auto,   $TREND_MIN) // $T_NOTREND) . ' · источник: git log · ISO-недели UTC, порог ≥3 непустых';
my $v2_t_init = (v2_trend(\%wk_init_d, $TREND_MIN) // $T_NOTREND) . ' · источник: audit.md init · ISO-недели UTC, порог ≥3 непустых';
my $v2_t_rev  = (v2_trend(\%wk_rev_d,  $TREND_MIN) // $T_NOTREND) . ' · источник: audit.md user-approval revise · ISO-недели UTC, порог ≥3 непустых';

# ── autonomy v2 (spec 006): стоимость прогона (FR-5/FR-6) — NFR-6: источник/выборка/порог в строке ──
my $budget = ($ENV{RUN_TOKEN_BUDGET} // '') =~ /^([1-9]\d*)$/ ? $1 : 0;  # guard FR-6: 0/нечисловой = не задан
my ($v2_cost, $v2_cost_cls) = (undef, '');
if ($v2_ucov) {
  my $med  = median(@v2_umed);
  my $srcs = join(',', sort keys %v2_usrc);
  $v2_cost = sprintf('%d токенов за окно · медиана %d на прогон (%d из %d прогонов окна с usage-данными) · источник: audit.md usage:* (source=%s)',
                     $v2_usum, $med, $v2_ucov, $v2_act, $srcs);
  if ($budget) {
    my $pct = sprintf('%.0f', 100 * $med / $budget);
    $v2_cost .= " · медиана = $pct% бюджета (порог RUN_TOKEN_BUDGET=$budget)";
    $v2_cost_cls = $pct <= 100 ? 'ok' : 'bad';
  }
} else {
  $v2_cost = 'нет данных (usage-события не пишутся; конвенция — шапка pipeline-state.sh)';
}

# eval-harness (spec 011 FR-8): % Resolved из tests/agent-evals/last-run.json — АДДИТИВНО и graceful.
# Отсутствие файла / битый JSON → $eval_pct undef → плитка НЕ печатается → вывод побайтово = до-011
# базлайн (устав: CORE-код инертен для отсутствующего mothership-only артефакта; SC-9). JSON::PP core.
my ($eval_pct, $eval_gate);
if (($ENV{EVAL_JSON} // '') ne '' && -f $ENV{EVAL_JSON}) {
  my $lr = eval {
    require JSON::PP;
    open(my $h, '<:raw', $ENV{EVAL_JSON}) or die;
    local $/; JSON::PP::decode_json(scalar <$h>);
  };
  if (ref $lr eq 'HASH' && defined $lr->{pct_resolved}) {
    $eval_pct  = "$lr->{pct_resolved}% ($lr->{resolved}/$lr->{total})";
    $eval_gate = $lr->{invariant_gate};
  }
}

if ($mode eq 'html') {
  my $cls = $auto_ok ? 'ok' : (defined $auto ? 'bad' : 'pending');
  print qq{<h2>DORA &middot; окно ${days}д</h2><div class="wrap"><table>\n};
  print qq{<tr><th>Метрика</th><th>Значение</th></tr>\n};
  print qq{<tr><td>&#128640; Deployment Frequency</td><td>$freq</td></tr>\n};
  print qq{<tr><td>&#9201;&#65039; Lead Time (init&rarr;PASS)</td><td>$lead</td></tr>\n};
  print qq{<tr><td>&#128165; Change Failure Rate</td><td>$cfr</td></tr>\n};
  print qq{<tr><td>&#128736;&#65039; MTTR</td><td>$mttr</td></tr>\n};
  print qq{<tr><td>&#129302; <b>Автономия (цель &ge;$target%)</b></td><td class="$cls">$auto_s</td></tr>\n};
  print qq{<tr><td>&#128737;&#65039; Гейты владельца</td><td>$gates</td></tr>\n};
  # ticket flow — строки ВНУТРИ той же таблицы: pipeline-dashboard.sh подхватывает без правок (FR-5)
  if (defined $t_src_s) {
    print qq{<tr><td>&#127915; Ticket flow &middot; источник</td><td>$t_src_s</td></tr>\n};
    print qq{<tr><td>&#9201;&#65039; Ticket lead time (created&rarr;closed)</td><td>$t_lead</td></tr>\n};
    print qq{<tr><td>&#128194; Тикетов открыто</td><td>$t_open</td></tr>\n};
    print qq{<tr><td>&#129302; Доля агентных тикетов</td><td>$t_agent</td></tr>\n};
    print qq{<tr><td>&#128257; Reopen rate</td><td>$t_reopen</td></tr>\n};
  } else {
    print qq{<tr><td>&#127915; Ticket flow</td><td>$t_nodata</td></tr>\n};
  }
  # ── autonomy v2 (spec 006 FR-8): аддитивные строки СТРОГО ПОСЛЕ блока ticket-flow, ВНУТРИ той же
  #    таблицы (паттерн spec 002 FR-5); значения с внешним текстом — через локальный esc() (SEC-5/D-6)
  print qq{<tr><td>&#127919; Intervention rate</td><td>} . esc($v2_ir) . qq{</td></tr>\n};
  print qq{<tr><td>&#129309; Merged-as-is</td><td>} . esc($v2_ma) . qq{</td></tr>\n};
  print qq{<tr><td>&#127915; Прогоны с тикетом</td><td>} . esc($v2_tc) . qq{</td></tr>\n};
  print qq{<tr><td>&#128279; Коммиты с тикет-ссылкой</td><td>} . esc($v2_cr) . qq{</td></tr>\n};
  print qq{<tr><td>&#8505;&#65039; автономия &middot; сноска</td><td>} . esc($v2_fn) . qq{</td></tr>\n};
  my $costcls = $v2_cost_cls ? qq{ class="$v2_cost_cls"} : '';
  print qq{<tr><td>&#128176; Стоимость &middot; токены</td><td$costcls>} . esc($v2_cost) . qq{</td></tr>\n};
  print qq{<tr><td>&#128200; Тренд &middot; автономия/нед</td><td>} . esc($v2_t_auto) . qq{</td></tr>\n};
  print qq{<tr><td>&#128200; Тренд &middot; init-прогоны/нед</td><td>} . esc($v2_t_init) . qq{</td></tr>\n};
  print qq{<tr><td>&#128200; Тренд &middot; revise/нед</td><td>} . esc($v2_t_rev) . qq{</td></tr>\n};
  print qq{<tr><td class="warn">&#9888;&#65039; Cross-check осей</td><td class="warn">} . esc($v2_xchk) . qq{</td></tr>\n} if defined $v2_xchk;
  print qq{<tr><td>&#128739;&#65039; Дорожки закрытых тикетов</td><td>} . esc($v2_tracks) . qq{</td></tr>\n};
  print qq{<tr><td>&#128739;&#65039; &middot; spec-pipeline</td><td>} . esc($v2_tr_a) . qq{</td></tr>\n} if defined $v2_tr_a;
  print qq{<tr><td>&#128739;&#65039; &middot; speckit</td><td>} . esc($v2_tr_b) . qq{</td></tr>\n} if defined $v2_tr_b;
  print qq{<tr><td>&#128739;&#65039; &middot; прямой фикс</td><td>} . esc($v2_tr_c) . qq{</td></tr>\n} if defined $v2_tr_c;
  print qq{<tr><td class="warn">&#9888;&#65039; Прямые фиксы &gt; порога</td><td class="warn">} . esc($v2_fr20) . qq{</td></tr>\n} if defined $v2_fr20;
  # eval-harness плитка (spec 011 FR-8): печатается ТОЛЬКО при наличии last-run.json (иначе инертно, SC-9)
  print qq{<tr><td>&#129514; % Resolved (eval &middot; gate=} . esc($eval_gate) . qq{)</td><td>} . esc($eval_pct) . qq{</td></tr>\n} if defined $eval_pct;
  print qq{</table></div>\n};
} else {
  print "DORA (окно ${days}д):\n";
  print "  deployment frequency : $freq\n";
  print "  lead time            : $lead\n";
  print "  change failure rate  : $cfr\n";
  print "  mttr                 : $mttr\n";
  printf "  автономия            : %s — %s цели ≥%d%%\n", $auto_s, ($auto_ok ? 'ДОСТИГАЕТ' : 'НЕ достигает'), $target;
  print "  гейты владельца      : $gates\n";
  if (defined $t_src_s) {
    print "  тикеты · источник    : $t_src_s\n";
    print "  тикеты · lead time   : $t_lead\n";
    print "  тикеты · открыто     : $t_open\n";
    print "  тикеты · агентные    : $t_agent\n";
    print "  тикеты · reopen      : $t_reopen\n";
  } else {
    print "  тикеты (ticket flow) : $t_nodata\n";
  }
  # autonomy v2 — те же строки, что в --html (FR-8/FR-14: режимы симметричны)
  print "  intervention rate    : $v2_ir\n";
  print "  merged-as-is         : $v2_ma\n";
  print "  прогоны с тикетом    : $v2_tc\n";
  print "  коммиты с тикет-ссылкой : $v2_cr\n";
  print "  автономия · сноска   : $v2_fn\n";
  print "  стоимость · токены   : $v2_cost\n";
  print "  тренд · автономия    : $v2_t_auto\n";
  print "  тренд · init-прогоны : $v2_t_init\n";
  print "  тренд · revise       : $v2_t_rev\n";
  print "  cross-check осей     : $v2_xchk\n" if defined $v2_xchk;
  print "  дорожки закрытых     : $v2_tracks\n";
  print "  · spec-pipeline      : $v2_tr_a\n" if defined $v2_tr_a;
  print "  · speckit            : $v2_tr_b\n" if defined $v2_tr_b;
  print "  · прямой фикс        : $v2_tr_c\n" if defined $v2_tr_c;
  print "  прямые фиксы > порога: $v2_fr20\n" if defined $v2_fr20;
  print "  % Resolved (eval)    : $eval_pct · gate=$eval_gate\n" if defined $eval_pct;
}
PERL
