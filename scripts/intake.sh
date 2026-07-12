#!/usr/bin/env bash
# intake.sh — детерминированная связка «тикет ↔ SPEC_DIR» канала /intake (spec 005).
#
# Зачем скрипт, а не промпт: транзакционная цепочка dedup → create → verify-read → link-ticket
# исполняется одним bash-процессом с проверяемыми исходами (I-16, паттерн pipeline-state.sh);
# классификация фразы остаётся в промпт-слое .claude/commands/intake.md (решение Д-1 spec 005).
# init SPEC_DIR здесь НЕ вызывается — порядок «init ДО тикета» держит intake.md (Д-2).
#
# Usage:
#   bash scripts/intake.sh ticket <SPEC_DIR> "<summary>" [body]   # body: 4-й аргумент или stdin
#
# Контракт stdout — РОВНО одна строка-исход (весь сервисный вывод уходит в stderr):
#   created:<KEY>                  — тикет создан (или найден dedup'ом), verify-read пройден,
#                                    link-ticket записан; exit 0
#   deferred:<причина>[ KEY=<key>] — тикет отложен (бэкенды недоступны / public-repo guard /
#                                    verify-read не прошёл); exit 0 — спека стартует без Ticket:
#   error:<причина>                — непредвиденный сбой самой связки; exit 1
#
# Параметры (ENV приоритетнее team.params корня репо; паттерн tp_param из agent-preflight.sh):
#   ISSUE_BACKEND (github) · TRACKER_TOOL · TRACKER_QUEUE ·
#   INTAKE_TICKET_TYPE (task) · INTAKE_TICKET_PRIORITY (normal) — атрибуты tracker-тикета ·
#   INTAKE_AUTHOR (Owner) — префикс авторства summary/body (агентские вызовы: INTAKE_AUTHOR=<Имя>) ·
#   INTAKE_ALLOW_PUBLIC=1 — явное разрешение создать issue в ПУБЛИЧНОМ репозитории (SEC-1)
set -uo pipefail

SELF_DIR="$(cd "$(dirname "$0")" && pwd)"
CMD="${1:?usage: intake.sh ticket <SPEC_DIR> \"<summary>\" [body]}"
[ "$CMD" = "ticket" ] || { echo "intake: FATAL: неизвестная команда '$CMD' (поддерживается: ticket)" >&2; exit 2; }
SPEC_DIR="${2:?SPEC_DIR required}"
SUMMARY_RAW="${3:?summary required}"
BODY_RAW=""
if [ $# -ge 4 ]; then BODY_RAW="$4"
elif [ ! -t 0 ]; then BODY_RAW="$(cat)"; fi
[ -n "$BODY_RAW" ] || BODY_RAW="$SUMMARY_RAW"

# per-run tmp + trap-очистка (паттерн agent-preflight.sh)
tmpdir="$(mktemp -d "${TMPDIR:-/tmp}/intake.XXXXXX")"
trap 'rm -rf "$tmpdir"' EXIT

repo_root="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
tp_param() { sed -n "s/^$1=\"\([^\"]*\)\".*\$/\1/p" "$repo_root/team.params" 2>/dev/null | head -1; }

# Секрет-дисциплина (боевой урок 51ca2698, тот же redact-паттерн agent-preflight.sh):
# любой перехваченный вывод create/verify редактируется ДО попадания в исход/лог (SEC-2)
redact_tokens() {
  perl -pe 's/\b(authorization|bearer|token|api[-_]?key)\b(["\x27:=\s]*)\S{8,}/$1$2***/gi; s/[A-Za-z0-9_-]{32,}/***/g'
}
reason_from() { # $1 файл с перехваченным выводом CLI — redact на границе перехвата, до записи исхода
  local r
  r="$(redact_tokens < "$1" | head -1)"
  printf '%s' "${r:-CLI без вывода}"
}

# Все сетевые вызовы — под perl-alarm 15 сек (ROB-1/NFR-3: деградация в deferred детерминирована,
# зависание невозможно; переносимый паттерн agent-preflight.sh, bash 3.2 / macOS)
net() { perl -e 'alarm shift; exec @ARGV' 15 "$@"; }

# ISSUE_BACKEND/TRACKER_* — ENV → team.params → дефолт (FR-7; путь xt.py не хардкодится)
ISSUE_BACKEND="${ISSUE_BACKEND:-}"; [ -n "$ISSUE_BACKEND" ] || ISSUE_BACKEND="$(tp_param ISSUE_BACKEND)"; [ -n "$ISSUE_BACKEND" ] || ISSUE_BACKEND="github"
TRACKER_TOOL="${TRACKER_TOOL:-}";   [ -n "$TRACKER_TOOL" ]  || TRACKER_TOOL="$(tp_param TRACKER_TOOL)"
TRACKER_QUEUE="${TRACKER_QUEUE:-}"; [ -n "$TRACKER_QUEUE" ] || TRACKER_QUEUE="$(tp_param TRACKER_QUEUE)"
# атрибуты owner-тикета tracker-бэкенда — mode-параметры, не плейсхолдеры (spec 005 Known Risk 2)
INTAKE_TICKET_TYPE="${INTAKE_TICKET_TYPE:-}";         [ -n "$INTAKE_TICKET_TYPE" ]     || INTAKE_TICKET_TYPE="$(tp_param INTAKE_TICKET_TYPE)";     [ -n "$INTAKE_TICKET_TYPE" ]     || INTAKE_TICKET_TYPE="task"
INTAKE_TICKET_PRIORITY="${INTAKE_TICKET_PRIORITY:-}"; [ -n "$INTAKE_TICKET_PRIORITY" ] || INTAKE_TICKET_PRIORITY="$(tp_param INTAKE_TICKET_PRIORITY)"; [ -n "$INTAKE_TICKET_PRIORITY" ] || INTAKE_TICKET_PRIORITY="normal"
INTAKE_AUTHOR="${INTAKE_AUTHOR:-Owner}"

# Авторство (FR-12, Д-5): [Owner]/[<Имя агента>] — первый токен И summary, И body;
# тело = префикс + дословная фраза + дата + ссылка на SPEC_DIR (A-5, Known Risk 1)
SUMMARY="[$INTAKE_AUTHOR] $SUMMARY_RAW"
BODY="[$INTAKE_AUTHOR] $BODY_RAW

Дата: $(date +%F)
SPEC_DIR: $SPEC_DIR"

# audit.md — ТОЛЬКО штатным инструментом (I-3); сбой следа не роняет создание тикета (I-8)
trace() { bash "$SELF_DIR/pipeline-state.sh" event "$SPEC_DIR" "$1" "${2:-}" >/dev/null 2>&1 || true; }

finish_created() { # $1 KEY, $2 backend-примечание
  trace "ticket:create:outcome" "created:$1 · $2"
  echo "created:$1"
  exit 0
}
finish_deferred() { # $1 причина, $2 KEY (опц.); deferred = exit 0 — спека обязана стартовать (FR-10, I-8)
  local key="${2:-}"
  trace "ticket:create:outcome" "deferred:$1${key:+ KEY=$key}"
  echo "intake: Тикет отложен: $1 — спека стартует без Ticket:, догон: bash scripts/pipeline-state.sh link-ticket $SPEC_DIR ${key:-<KEY>}" >&2
  echo "deferred:$1${key:+ KEY=$key}"
  exit 0
}
finish_error() { # непредвиденный сбой связки — честный exit 1
  trace "ticket:create:outcome" "error:$1"
  echo "error:$1"
  exit 1
}

verify_and_link() { # $1 KEY · $2 backend-примечание · $3.. команда verify-read (argv, без склейки)
  local key="$1" note="$2"; shift 2
  # zero-trust (I-13, FR-8): без успешного verify-read link-ticket не вызывается
  if ! net "$@" >"$tmpdir/view.out" 2>"$tmpdir/view.err"; then
    finish_deferred "verify-failed" "$key"
  fi
  bash "$SELF_DIR/pipeline-state.sh" link-ticket "$SPEC_DIR" "$key" >/dev/null 2>&1 \
    || finish_deferred "link-ticket-провал (тикет создан и проверен, довяжи рецептом ниже)" "$key"
  finish_created "$key" "$note"
}

github_ticket() { # основная ветка backend=github И VPN-фолбэк tracker-ветки (FR-9)
  local note="${1:-github}"
  command -v gh >/dev/null 2>&1 || finish_deferred "gh-недоступен (CLI не найден)"
  # SEC-1 public-repo guard: дословная фраза владельца не уходит в публичный репозиторий молча
  if ! net gh repo view --json visibility >"$tmpdir/vis.out" 2>"$tmpdir/vis.err"; then
    finish_deferred "gh-недоступен: $(reason_from "$tmpdir/vis.err")"
  fi
  if grep -qiE '"visibility"[[:space:]]*:[[:space:]]*"public"' "$tmpdir/vis.out" && [ "${INTAKE_ALLOW_PUBLIC:-0}" != "1" ]; then
    echo "intake: репозиторий PUBLIC — создание отклонено; после явного confirm владельца повтори вызов с INTAKE_ALLOW_PUBLIC=1" >&2
    finish_deferred "public-repo"
  fi
  # FR-9: dedup ОБЯЗАТЕЛЕН до create (закрытие дыры spec 002); поиск недоступен → вслепую не создаём
  if ! net gh issue list --search "$SUMMARY_RAW" --state all >"$tmpdir/list.out" 2>"$tmpdir/list.err"; then
    finish_deferred "gh-поиск-недоступен: $(reason_from "$tmpdir/list.err")"
  fi
  local dup num
  dup="$(redact_tokens < "$tmpdir/list.out" | awk 'NR==1 && $1 ~ /^[0-9]+$/ {print $1}')"
  if [ -n "$dup" ]; then
    trace "ticket:create:attempt" "backend=$note dedup=hit #$dup — новый тикет не создаётся"
    verify_and_link "#$dup" "$note (dedup: найден существующий)" gh issue view "$dup"
  fi
  if ! printf '%s\n' "$BODY" | net gh issue create --title "$SUMMARY" --body-file - >"$tmpdir/create.out" 2>"$tmpdir/create.err"; then
    finish_deferred "gh-create-провал: $(reason_from "$tmpdir/create.err")"
  fi
  num="$(redact_tokens < "$tmpdir/create.out" | grep -oE '/issues/[0-9]+' | head -1 | grep -oE '[0-9]+')"
  [ -n "$num" ] || finish_error "gh-create прошёл, но номер issue не распознан: $(reason_from "$tmpdir/create.out")"
  verify_and_link "#$num" "$note" gh issue view "$num"
}

tracker_ticket() { # протокол XTRACKER_FILING.md шаг-в-шаг: ping → (фолбэк gh) → create → verify-read
  local tool="$TRACKER_TOOL"
  if [ -z "$tool" ] || [ "$tool" = "-" ] || [ -z "$TRACKER_QUEUE" ] || [ "$TRACKER_QUEUE" = "-" ]; then
    trace "ticket:create:attempt" "backend=tracker → gh-фолбэк (TRACKER_TOOL/TRACKER_QUEUE не заданы)"
    github_ticket "gh-фолбэк (tracker не сконфигурирован)"
  fi
  case "$tool" in /*) ;; *) tool="$repo_root/$tool";; esac  # путь от repo_root, не от cwd (паттерн preflight)
  if [ ! -f "$tool" ] || ! command -v python3 >/dev/null 2>&1; then
    trace "ticket:create:attempt" "backend=tracker → gh-фолбэк (CLI/python3 недоступны)"
    github_ticket "gh-фолбэк (tracker-CLI недоступен)"
  fi
  # шаг 1 протокола: ping (VPN-чек); провал = штатный фолбэк gh, не имитация успеха
  if ! net python3 "$tool" ping >"$tmpdir/ping.out" 2>&1; then
    trace "ticket:create:attempt" "backend=tracker → gh-фолбэк (ping fail)"
    github_ticket "gh-фолбэк (tracker ping fail)"
  fi
  # шаги 2–3: create (dedup встроен в create самого CLI → повторный summary возвращает существующий KEY)
  if ! printf '%s\n' "$BODY" | net python3 "$tool" issue create --queue "$TRACKER_QUEUE" --summary "$SUMMARY" --type "$INTAKE_TICKET_TYPE" --priority "$INTAKE_TICKET_PRIORITY" --body-file - >"$tmpdir/create.out" 2>"$tmpdir/create.err"; then
    trace "ticket:create:attempt" "backend=tracker → gh-фолбэк (create fail)"
    github_ticket "gh-фолбэк (tracker create fail)"
  fi
  local key
  key="$(redact_tokens < "$tmpdir/create.out" | grep -oE '[A-Za-z][A-Za-z0-9_]*-[0-9]+' | head -1)"
  [ -n "$key" ] || finish_error "tracker-create прошёл, но KEY не распознан: $(reason_from "$tmpdir/create.out")"
  # шаг 4 протокола: verify-read; шаг 5 (link) — только после него
  verify_and_link "$key" "tracker" python3 "$tool" issue view "$key"
}

# FR-11 (I-9): след попытки — ДО вызова бэкенда; дубль при ретрае виден в audit.md постфактум
trace "ticket:create:attempt" "backend=$ISSUE_BACKEND · $SUMMARY"
case "$ISSUE_BACKEND" in
  tracker) tracker_ticket ;;
  *)       github_ticket "github" ;;
esac
finish_error "недостижимая ветка исполнения (ни один исход не сработал)"
