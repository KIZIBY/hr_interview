#!/usr/bin/env bash
# plan-lint.sh — детерминированный линт plan.md + traceability требований (сенсор stage-2).
#
# Две проверки:
#   1. Структура plan.md: REQUIRED-секции (контракт /pipeline-stage2), стеко-зависимые — warn.
#   2. Traceability: каждый FR-xxx / NFR-xxx из spec.md упомянут в plan.md ИЛИ tasks.md —
#      требование без следа в плане = осиротевшее (аналог upstream-coverage sensor в AI-DLC);
#      план обязан отвечать на каждое требование, иначе stage-4 найдёт MISSING слишком поздно.
#
# Usage: bash scripts/plan-lint.sh <SPEC_DIR>
# Exit:  0 = OK (warn допустимы) · 1 = нет REQUIRED-секции / осиротевшие требования · 2 = файлы не найдены
set -uo pipefail

DIR="${1:?usage: plan-lint.sh <SPEC_DIR>}"
PLAN="$DIR/plan.md"; SPEC="$DIR/spec.md"; TASKS="$DIR/tasks.md"
[ -f "$PLAN" ] || { echo "plan-lint: FATAL: не найден $PLAN" >&2; exit 2; }
[ -f "$SPEC" ] || { echo "plan-lint: FATAL: не найден $SPEC (traceability без спеки не считается)" >&2; exit 2; }

fail=0
req() { if grep -q "^## $1" "$PLAN"; then echo "plan-lint: ok    ## $1"
        else echo "plan-lint: FAIL  нет секции '## $1' (REQUIRED)"; fail=1; fi; }
rec() { if grep -q "^## $1" "$PLAN"; then echo "plan-lint: ok    ## $1"
        else echo "plan-lint: warn  нет секции '## $1' (RECOMMENDED)"; fi; }

req "Technical Approach"
req "Implementation Steps"
req "Known Risks"
rec "Units of Work"
rec "Files to Create/Modify"

# --- traceability: FR/NFR из spec.md → plan.md (или tasks.md, если есть) ---
# Требование должно быть адресовано хоть где-то в «покрытом корпусе» plan (+tasks).
has_tasks=0; tasks_note=""
[ -f "$TASKS" ] && { has_tasks=1; tasks_note="/tasks.md"; }
in_corpus() { # $1 = id
  grep -qE "\b$1\b" "$PLAN" && return 0
  [ "$has_tasks" -eq 1 ] && grep -qE "\b$1\b" "$TASKS" && return 0
  return 1
}
# ID собираются ТОЛЬКО из секций требований и только из ДЕКЛАРАЦИЙ: жирная (`**FR-N`) или
# в начале строки/пункта (`FR-N:`, `- FR-N`). Цитата чужого требования в середине прозы
# («прецедент spec 002 FR-19») — не декларация: иначе ложный сирота (боевой урок spec 004).
ids="$( { awk '/^## (Functional|Non-Functional) Requirements/{f=1;next} /^## /{f=0} f' "$SPEC" \
  | grep -ohE '\*\*N?FR-[0-9]+|^[-*0-9. ]*N?FR-[0-9]+' | grep -oE 'N?FR-[0-9]+' || true; } | sort -u)"
if [ -z "$ids" ]; then
  echo "plan-lint: warn  в spec.md нет ни одного FR-xxx/NFR-xxx — traceability проверить нечего (нумеруй требования)"
else
  orphans=""
  for id in $ids; do
    in_corpus "$id" || orphans="$orphans $id"
  done
  if [ -n "$orphans" ]; then
    echo "plan-lint: FAIL  осиротевшие требования (есть в spec.md, нет следа в plan.md$tasks_note):$orphans"
    echo "plan-lint:        каждое требование адресуется в плане явно — или переносится в Out of Scope спеки"
    fail=1
  else
    echo "plan-lint: ok    traceability: все $(echo "$ids" | wc -l | tr -d ' ') требований из spec.md адресованы в плане"
  fi
fi

if [ "$fail" -eq 0 ]; then echo "plan-lint: OK ($PLAN)"; else echo "plan-lint: FAILED ($PLAN)"; fi
exit "$fail"
