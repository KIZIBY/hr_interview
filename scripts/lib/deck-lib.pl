# scripts/lib/deck-lib.pl — общие perl-хелперы HTML-дашбордов пайплайна (Flight Deck / Fleet Deck).
#
# Происхождение: вынесено 1:1 из perl-heredoc scripts/pipeline-dashboard.sh (spec 004, юнит U-1).
# Назначение — анти-дрейф NFR-4: pipeline-dashboard.sh и fleet-dashboard.sh рендерят одни и те же
# state.md/audit.md; цвета, иконки и трактовка гейтов правятся ЗДЕСЬ один раз — параллельной
# ручной правки во втором генераторе не существует.
#
# Подключение (из perl-heredoc; SELF_DIR прокидывает bash-обёртка через ENV):
#   do "$ENV{SELF_DIR}/lib/deck-lib.pl" or die "...: " . ($@ || $!);
#
# Состав:
#   esc($s)         — HTML-экранирование (& < >)
#   ts2e($ts)       — ISO-8601 UTC → epoch; undef на битом/range-невалидном ts (месяц 13 и т.п.)
#   dur($sec)       — секунды → человекочитаемо (42s / 3m 05s / 2h 07m)
#   icon($c)        — чекбокс state.md ('x'|'-'|' ') → ✅ 🔵 ⬜
#   gate_cls($v)    — значение гейта → CSS-класс ok|bad|warn|pending
#   parse_state($d) — $d/state.md → hashref прогона: dir/disp/feature/scope/ticket (spec 002 FR-17;
#                     плейсхолдер «—» нормализуется в '')/started/updated/stages/gates/units +
#                     пустые rows/total под audit; undef, если state.md не открылся
#   parse_audit($d) — $d/audit.md → (\@rows, $total): строки таймлайна [ts, event, detail, dur]
#                     с FIFO-спариванием одноимённых :start/:done и общая длительность прогона
#
# Формат state.md/audit.md — frozen contract (I-6), генератор scripts/pipeline-state.sh.
# В адаптации файл едет каналом CORE_SCRIPTS (scripts/agent-team-adapt.sh) как зависимость
# pipeline-dashboard.sh. Библиотека без side effects: только subs, никакого I/O при загрузке.
use strict; use warnings; use utf8;
use Time::Local qw(timegm);
use Encode qw(decode);

sub esc { my $s = shift // ''; $s =~ s/&/&amp;/g; $s =~ s/</&lt;/g; $s =~ s/>/&gt;/g; $s }
# eval: формально-валидный, но range-невалидный ts (месяц 13, час 24…) в рукописной строке
# audit.md не должен ронять весь рендер — такая строка просто остаётся без epoch/длительности
sub ts2e { my $t = shift // ''; return $t =~ /^(\d{4})-(\d{2})-(\d{2})T(\d{2}):(\d{2}):(\d{2})Z/ ? eval { timegm($6,$5,$4,$3,$2-1,$1) } : undef }
sub dur { my $s = shift; return '' unless defined $s && $s >= 0;
  return $s < 60 ? "${s}s" : $s < 3600 ? sprintf("%dm %02ds",$s/60,$s%60) : sprintf("%dh %02dm",$s/3600,($s%3600)/60) }
sub icon { my $c = shift // ' '; return $c eq 'x' ? '&#9989;' : $c eq '-' ? '&#128309;' : '&#11036;' } # ✅ 🔵 ⬜
sub gate_cls { my $v = shift // "\x{2014}";
  return 'pending' if $v =~ /^\x{2014}/ || $v eq '' || $v eq '-';
  return 'bad' if $v =~ /MUST-FLAG:\s*[1-9]/ || $v =~ /^(FAIL|abort)/;
  return 'ok'  if $v =~ /MUST-FLAG:\s*0(?![0-9])/ || $v =~ /^(approved|PASS)/;
  return 'warn' }

sub parse_state {
  my ($d) = @_;
  # $d — байты из ARGV (для open); disp — декодированная строка для вывода в :utf8 STDOUT
  # (иначе кириллические имена каталогов рендерятся дважды закодированными).
  # decode с CHECK потребляет исходник in-place — передаём КОПИЮ, иначе $d пустеет и open ломается
  my $bytes = $d;
  my $disp = eval { decode('UTF-8', $bytes, Encode::FB_CROAK) } // $d;
  my %r = (dir=>$d, disp=>$disp, feature=>'', scope=>'', ticket=>'', started=>'', updated=>'', stages=>[], gates=>{}, units=>[], rows=>[], total=>'');
  open(my $f, '<:utf8', "$d/state.md") or return undef;
  while (<$f>) {
    chomp;
    if    (/^# Pipeline State \x{2014} (.*)/)                    { $r{feature} = $1 }
    elsif (/^- Scope: (.*)/)                                     { $r{scope} = $1 }
    # spec 002 FR-17: связь прогона с тикетом; «—» = плейсхолдер «без тикета», не рендерим
    elsif (/^- Ticket: (.*)/)                                    { $r{ticket} = $1 eq "\x{2014}" ? '' : $1 }
    elsif (/^- Started: (.*)/)                                   { $r{started} = $1 }
    elsif (/^- Updated: (.*)/)                                   { $r{updated} = $1 }
    elsif (/^- \[([ x-])\] (stage-\S+)/)                         { push @{$r{stages}}, [$2, $1] }
    elsif (/^- \[([ x-])\] unit:(.*)/)                           { push @{$r{units}}, [$2, $1] }
    elsif (/^- (constitution-gate|user-approval|quality-verdict): (.*)/) { $r{gates}{$1} = $2 }
  }
  close $f;
  return \%r;
}

# pair_events — ЧИСТЫЙ парсер audit.md с FIFO-спариванием :start/:done (spec 010 ARCH-1).
# Единственный источник спаривания для ОБОИХ потребителей: Flight Deck (parse_audit ниже,
# берёт 4-tuple) И конвертер audit-to-otel.sh (берёт epoch/start_epoch для OTLP-спанов).
# Разъезд двух копий спаривания = дрейф NFR-4, ради которого deck-lib и создан — поэтому один сток.
# Возвращает (\@events, $total, $first_epoch, $last_epoch); каждое событие — хэш:
#   { ts, epoch, event, detail, dur (строка), start_epoch (для :done — эпоха спаренного :start, иначе undef) }
sub pair_events {
  my ($d) = @_;
  my (@ev, %startq, $first, $last);
  if (open(my $a, '<:utf8', "$d/audit.md")) {
    while (<$a>) {
      chomp;
      next unless /^\| (.*?) \| (.*?) \| (.*?) \|$/;
      my ($ts, $name, $det) = ($1, $2, $3);
      next if $ts eq 'ts (UTC)' || $ts =~ /^-+$/;
      my $e = ts2e($ts);
      if (defined $e) { $first //= $e; $last = $e }
      my ($dd, $se) = ('', undef);
      # FIFO-очередь per имя: параллельные одноимённые агенты спариваются первый-start ↔ первый-done
      # (точная атрибуция при пересечении невозможна из плоского журнала — очередь честнее перезаписи)
      if    ($name =~ /^(.*):start$/) { push @{$startq{$1}}, $e }
      elsif ($name =~ /^(.*):done$/ && @{$startq{$1} // []}) {
        my $s = shift @{$startq{$1}};
        if (defined $s) { $se = $s; $dd = dur($e - $s) if defined $e }
      }
      push @ev, { ts=>$ts, epoch=>$e, event=>$name, detail=>$det, dur=>$dd, start_epoch=>$se };
    }
    close $a;
  }
  my $total = (defined $first && defined $last) ? dur($last - $first) : '';
  return (\@ev, $total, $first, $last);
}

sub parse_audit {
  my ($d) = @_;
  my ($ev, $total) = pair_events($d);   # ARCH-1: дашборд потребляет тот же чистый спариватель
  my @rows = map { [ $_->{ts}, $_->{event}, $_->{detail}, $_->{dur} ] } @$ev;
  return (\@rows, $total);
}

1;
