#!/usr/bin/env bash
# ops-log.sh — репо-уровневый append-only журнал эксплуатации: docs/ops-journal.md.
#
# Источник DORA-метрик (scripts/dora-metrics.sh) для событий, живущих ВНЕ прогонов пайплайна:
#   deploy:start | deploy:done | deploy:failed      — detail: sha/scope (деплой-скрипт зовёт сам)
#   incident:open <slug> | incident:resolved <slug> — slug ПЕРВЫМ словом detail (MTTR-пара)
# Произвольные события допустимы. Формат строки = audit.md (| ts | event | detail |);
# '|' и переводы строк санируются (целостность таблицы).
#
# Usage: bash scripts/ops-log.sh <event> [detail]
set -euo pipefail

ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
J="$ROOT/docs/ops-journal.md"
EV="${1:?event required (напр.: deploy:done | incident:open p1-export-hang)}"
DET="${2:--}"
EV="${EV//|/∕}";  EV="${EV//$'\n'/ }"
DET="${DET//|/∕}"; DET="${DET//$'\n'/ }"
TS="$(date -u +%FT%TZ)"

if [ ! -f "$J" ]; then
  mkdir -p "$ROOT/docs"
  printf '# Ops Journal — append-only журнал эксплуатации (пишет scripts/ops-log.sh)\n\n' > "$J"
  printf 'DORA-события: `deploy:start|done|failed` · `incident:open|resolved <slug>`; читает `scripts/dora-metrics.sh`.\n\n' >> "$J"
  printf '| ts (UTC) | event | detail |\n|---|---|---|\n' >> "$J"
fi
printf '| %s | %s | %s |\n' "$TS" "$EV" "$DET" >> "$J"
echo "ops-log: $EV${DET:+ — $DET}"
