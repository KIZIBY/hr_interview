#!/usr/bin/env bash
# pipeline-state.sh — state-машина 4-этапного /pipeline (автономия P1: resume + детерминированные гейты).
#
# Per-SPEC_DIR файлы:
#   state.md — чекбоксы этапов + статусы гейтов (источник истины для resume);
#   audit.md — append-only журнал событий пайплайна (кто/когда/что решил).
#
# Зачем скрипт, а не промпт: гейты в тексте команд модель может «проскочить».
# `check` (и `stage-start` внутри) возвращает exit != 0 — stage-3 механически не стартует
# без user-approval=approved и `MUST-FLAG: 0`, даже если этап-промпт забыл про гейт.
# NEEDS-INFO на MUST-инварианте различить из строки итога нельзя — это остаётся на
# процедуре constitution-check (script проверяет только MUST-FLAG: 0).
#
# Usage:
#   bash scripts/pipeline-state.sh init        <SPEC_DIR> "<описание фичи>" [scope] [ticket]   # scope: feature|enterprise (по умолчанию feature); ticket — ключ тикета-источника (BOARD-52 / #123), строго 5-й позиционный (spec 002 FR-14)
#   bash scripts/pipeline-state.sh link-ticket <SPEC_DIR> <ticket>   # пост-фактум привязка тикета; идемпотентна (тот же KEY = no-op без дубля события)
#   bash scripts/pipeline-state.sh stage-start <SPEC_DIR> <stage>
#   bash scripts/pipeline-state.sh stage-done  <SPEC_DIR> <stage>
#   bash scripts/pipeline-state.sh gate        <SPEC_DIR> "MUST-FLAG: 0 · SHOULD-FLAG: 2 · NEEDS-INFO: 0"
#   bash scripts/pipeline-state.sh approve     <SPEC_DIR> <approved|revise|abort> [кто]
#   bash scripts/pipeline-state.sh units-set   <SPEC_DIR> "unit-a,unit-b,unit-c"   # юниты из plan.md (§Units of Work)
#   bash scripts/pipeline-state.sh unit-done   <SPEC_DIR> <unit>   # ТОЛЬКО после своего прогона convergence-check юнита
#   bash scripts/pipeline-state.sh verdict     <SPEC_DIR> <PASS|FAIL> [детали]
#   bash scripts/pipeline-state.sh event       <SPEC_DIR> "<event>" ["detail"]   # произвольное trace-событие в audit.md
#   bash scripts/pipeline-state.sh check       <SPEC_DIR> <stage>   # exit 0 = этап можно стартовать
#   bash scripts/pipeline-state.sh status      <SPEC_DIR>           # state + next (для resume)
# Конвенция имён event (OTel GenAI-совместимая, читает pipeline-dashboard.sh):
#   agent:<имя>:start и agent:<имя>:done — спавн/финиш субагента (≈ invoke_agent); detail = задача/summary
#   tool:<имя>                           — значимый tool-вызов (≈ execute_tool); произвольные имена допустимы
#   usage:agent:<имя> · usage:stage-N    — фактический расход токенов (spec 006 FR-4); detail — плоские
#       пары: tokens=<int> [in=<int> out=<int>] [model=<id>] source=<subagent-report|hook|cli>.
#       КОНТРАКТ ЧЕСТНОСТИ (I-13): событие пишется ТОЛЬКО из реальных данных среды (отчёт
#       Agent-инструмента, hook, CLI-отчёт); оценка модели «по ощущениям» запрещена; расход самого
#       оркестратора не пишется, пока среда его не отдаёт. Без tokens=<int> И непустого source=
#       событие не засчитывается парсером dora-metrics.sh (D-3, исполняемый guard I-16).
#   intervention:manual                  — opt-in декларация ручной правки владельца мимо гейта
#       (spec 006 FR-3): счётчик-аннотация к intervention rate, в формулу НЕ входит.
#   ВНИМАНИЕ (D-5): detail usage:*/intervention:manual попадает в ПУБЛИЧНЫЙ git-журнал audit.md —
#       без путей раннера, PII и названий приватных фич адаптаций (I-1).
#   символ '|' и переводы строк в event/detail заменяются при записи (целостность таблицы audit.md)
#   <stage> ::= stage-1-creative | stage-2-audit | stage-3-dev | stage-4-quality
# Units опциональны (мелкая фича = без юнитов); если секция ## Units есть в state.md,
# stage-4 не стартует, пока каждый юнит не отмечен unit-done.
set -euo pipefail

CMD="${1:?usage: pipeline-state.sh <init|link-ticket|stage-start|stage-done|gate|approve|verdict|check|status> <SPEC_DIR> [...]}"
DIR="${2:?SPEC_DIR required}"
STATE="$DIR/state.md"; AUDIT="$DIR/audit.md"
TS="$(date -u +%FT%TZ)"
STAGES="stage-1-creative stage-2-audit stage-3-dev stage-4-quality"

die()  { echo "pipeline-state: FATAL: $*" >&2; exit 2; }
note() { echo "pipeline-state: $*"; }
need_state() { [ -f "$STATE" ] || die "нет $STATE — сначала: pipeline-state.sh init $DIR \"<фича>\""; }
valid_stage() { case " $STAGES " in *" $1 "*) return 0;; *) return 1;; esac; }

audit_row() { # $1 event, $2 detail; '|' и переводы строк заменяются в ОБОИХ полях —
  # иначе одна строка с пайпом/\n в имени события ломает markdown-таблицу и парсер дашборда
  local ev="$1" det="${2:--}"
  ev="${ev//|/∕}";  ev="${ev//$'\n'/ }"
  det="${det//|/∕}"; det="${det//$'\n'/ }"
  if [ ! -f "$AUDIT" ]; then
    mkdir -p "$DIR"
    printf '# Pipeline Audit — append-only журнал (пишет только scripts/pipeline-state.sh)\n\n| ts (UTC) | event | detail |\n|---|---|---|\n' > "$AUDIT"
  fi
  printf '| %s | %s | %s |\n' "$TS" "$ev" "$det" >> "$AUDIT"
}

mark_stage() { # $1 stage, $2 символ чекбокса (' '|'-'|'x')
  STAGE="$1" SYM="$2" perl -pi -e 's/^- \[[ x-]\] \Q$ENV{STAGE}\E$/- [$ENV{SYM}] $ENV{STAGE}/' "$STATE"
}
set_gate() { # $1 ключ (constitution-gate|user-approval|quality-verdict), $2 значение
  KEY="$1" VAL="$2" perl -pi -e 's/^- \Q$ENV{KEY}\E:.*$/- $ENV{KEY}: $ENV{VAL}/' "$STATE"
}
upd_ts() { TSV="$TS" perl -pi -e 's/^- Updated:.*$/- Updated: $ENV{TSV}/' "$STATE"; }

case "$CMD" in
  init)
    FEATURE="${3:-}"; SCOPE="${4:-feature}"; TICKET="${5:-}"  # ticket — строго 5-й позиционный, опционален (FR-14)
    case "$SCOPE" in feature|enterprise) ;; *) die "init: scope ожидаю feature|enterprise (bugfix маршрутизируется в docs/bug-handling-process.md ДО init), получил '$SCOPE'";; esac
    # санитизация как в audit_row: значение попадает в markdown-шапку state.md
    TICKET="${TICKET//|/∕}"; TICKET="${TICKET//$'\n'/ }"
    mkdir -p "$DIR"
    if [ -f "$STATE" ]; then
      note "state уже существует — это resume, init пропущен (data sacred). Статус:"
      exec bash "$0" status "$DIR"
    fi
    cat > "$STATE" <<EOF
# Pipeline State — ${FEATURE:-<фича не описана>}

- SPEC_DIR: $DIR
- Scope: $SCOPE
- Ticket: ${TICKET:-—}
- Started: $TS
- Updated: $TS

## Stages

- [ ] stage-1-creative
- [ ] stage-2-audit
- [ ] stage-3-dev
- [ ] stage-4-quality

## Gates

- constitution-gate: —
- user-approval: —
- quality-verdict: —

> Файл ведёт \`scripts/pipeline-state.sh\` — чекбоксы и гейты руками не редактируются;
> журнал событий — \`audit.md\` рядом (append-only).
EOF
    audit_row "init" "scope=$SCOPE · ${FEATURE:--}"
    if [ -n "$TICKET" ]; then audit_row "ticket:linked" "$TICKET"; fi
    note "state создан: $STATE (scope: $SCOPE${TICKET:+, ticket: $TICKET})"
    ;;

  link-ticket)
    # Пост-фактум привязка SPEC_DIR ↔ тикет (spec 002 G5, FR-15). Идемпотентность явная:
    # тот же KEY → no-op БЕЗ нового audit-события; другой KEY → overwrite + событие с деталью old → new.
    # Существование тикета в бэкенде здесь НЕ проверяется (state-машина обязана работать офлайн;
    # best-effort валидация FR-16 — забота оператора/этап-промптов, не гейт).
    KEY="${3:?ticket key required (напр. BOARD-52 или #123)}"
    need_state
    KEY="${KEY//|/∕}"; KEY="${KEY//$'\n'/ }"  # санитизация как в audit_row
    CUR="$(sed -n 's/^- Ticket: //p' "$STATE" | head -1)"
    if [ "$CUR" = "$KEY" ]; then
      note "link-ticket: тикет уже привязан ($KEY) — no-op (идемпотентность, событие не дублируется)"
    else
      if grep -q '^- Ticket:' "$STATE"; then
        KEYV="$KEY" perl -pi -e 's/^- Ticket:.*$/- Ticket: $ENV{KEYV}/' "$STATE"  # regex-замена по образцу set_gate()
      else
        # state.md, созданный до spec 002 — строки Ticket нет, вставляем в шапку после Scope
        KEYV="$KEY" perl -pi -e 's/^(- Scope: .*)$/$1\n- Ticket: $ENV{KEYV}/' "$STATE"
        grep -q '^- Ticket:' "$STATE" || die "link-ticket: в $STATE нет шапки со Scope — файл не похож на state.md"
      fi
      upd_ts
      if [ -n "$CUR" ] && [ "$CUR" != "—" ]; then
        audit_row "ticket:linked" "$CUR → $KEY"
      else
        audit_row "ticket:linked" "$KEY"
      fi
      note "link-ticket: $KEY → $STATE"
    fi
    # Догон FR-13-маркера (владелец «да» 2026-07-04): при пост-фактум привязке spec.md обязан нести
    # «Источник: тикет KEY» (канонический bullet, распознаётся spec-lint/dora-metrics). Advisory:
    # только если spec.md рядом; выполняется и на no-op (гарантирует маркер даже при повторной привязке).
    SP="$DIR/spec.md"
    if [ -f "$SP" ]; then
      if grep -qE '^[-*>]?[[:space:]]*Источник:.*[Тт]икет' "$SP"; then
        KEYV="$KEY" perl -pi -e 's/^[-*>]?\s*Источник:.*[Тт]икет.*$/- Источник: тикет $ENV{KEYV}/' "$SP"
      else
        KEYV="$KEY" perl -pi -e '$_ .= "\n- Источник: тикет $ENV{KEYV}\n" if $. == 1' "$SP"
      fi
      note "link-ticket: маркер «Источник: тикет $KEY» в spec.md (догон FR-13)"
    fi
    ;;

  units-set)
    LIST="${3:?список юнитов required: \"unit-a,unit-b\"}"
    need_state
    if grep -q '^## Units' "$STATE"; then
      grep -q '^- \[x\] unit:' "$STATE" && die "units-set: юниты уже есть и часть отмечена done — пере-задание уничтожило бы прогресс (data sacred); правь точечно"
      # секция Units всегда добавляется в конец файла — срезаем её и переписываем
      awk '/^## Units$/{exit} {print}' "$STATE" > "$STATE.tmp" && mv "$STATE.tmp" "$STATE"
    fi
    { echo "## Units"; echo; } >> "$STATE"
    IFS=','; for u in $LIST; do IFS=' '
      u="$(echo "$u" | tr -d ' ')"; [ -n "$u" ] || continue
      echo "- [ ] unit:$u" >> "$STATE"
    done
    upd_ts; audit_row "units-set" "$LIST"
    note "units заданы: $LIST (stage-4 заблокирован, пока каждый не unit-done)"
    ;;

  unit-done)
    U="${3:?имя юнита required}"
    need_state
    grep -q "^- \[[ x-]\] unit:$U\$" "$STATE" || die "unit-done: юнит '$U' не найден в ## Units (сначала units-set; имена — из plan.md)"
    UNIT="unit:$U" perl -pi -e 's/^- \[[ x-]\] \Q$ENV{UNIT}\E$/- [x] $ENV{UNIT}/' "$STATE"
    upd_ts; audit_row "unit-done" "$U"
    note "unit done: $U"
    ;;

  stage-start|stage-done)
    S="${3:?stage required (ожидаю: $STAGES)}"
    valid_stage "$S" || die "неизвестный этап '$S' (ожидаю: $STAGES)"
    need_state
    if [ "$CMD" = "stage-start" ]; then
      bash "$0" check "$DIR" "$S" || die "этап $S BLOCKED — причина выше; обход гейта запрещён"
      mark_stage "$S" "-"
    else
      mark_stage "$S" "x"
    fi
    upd_ts; audit_row "$S:${CMD#stage-}"
    note "$S → ${CMD#stage-}"
    ;;

  gate)
    RES="${3:?итог constitution-check required (строка 'MUST-FLAG: N · SHOULD-FLAG: N · NEEDS-INFO: N')}"
    need_state
    printf '%s' "$RES" | grep -q 'MUST-FLAG:' || die "в итоге нет 'MUST-FLAG:' — передай строку итога constitution-check"
    set_gate "constitution-gate" "$RES ($TS)"
    upd_ts; audit_row "constitution-gate" "$RES"
    note "constitution-gate: $RES"
    ;;

  approve)
    V="${3:?verdict required: approved|revise|abort}"; BY="${4:-owner}"
    case "$V" in approved|revise|abort) ;; *) die "approve: ожидаю approved|revise|abort, получил '$V'";; esac
    need_state
    if [ "$V" = "approved" ]; then
      grep -Eq '^- constitution-gate: .*MUST-FLAG: 0($|[^0-9])' "$STATE" \
        || die "approve=approved запрещён: constitution-gate не записан с MUST-FLAG: 0 (сначала 'gate'; MUST-FLAG устраняется в спеке или versioned-поправкой устава)"
    fi
    set_gate "user-approval" "$V ($TS, $BY)"
    upd_ts; audit_row "user-approval" "$V by $BY"
    note "user-approval: $V"
    ;;

  verdict)
    V="${3:?PASS|FAIL required}"; DET="${4:-}"
    case "$V" in PASS|FAIL) ;; *) die "verdict: ожидаю PASS|FAIL, получил '$V'";; esac
    need_state
    set_gate "quality-verdict" "$V${DET:+ — $DET} ($TS)"
    upd_ts; audit_row "quality-verdict" "$V${DET:+ — $DET}"
    note "quality-verdict: $V"
    ;;

  event)
    EV="${3:?event required (напр. \"agent:go-backend-developer:start\")}"; DET="${4:-}"
    need_state
    audit_row "$EV" "$DET"
    note "event: $EV"
    ;;

  check)
    S="${3:?stage required (ожидаю: $STAGES)}"
    valid_stage "$S" || die "неизвестный этап '$S' (ожидаю: $STAGES)"
    if [ ! -f "$STATE" ]; then
      if [ "$S" = "stage-1-creative" ]; then note "state ещё нет — stage-1 можно (init создаст)"; exit 0; fi
      echo "pipeline-state: BLOCKED $S: нет $STATE (сначала init и предыдущие этапы)" >&2; exit 1
    fi
    ok=0
    case "$S" in
      stage-1-creative) ;;   # первый этап: всегда можно (включая re-run после revise)
      stage-2-audit)
        grep -q '^- \[x\] stage-1-creative' "$STATE" \
          || { echo "pipeline-state: BLOCKED stage-2: stage-1-creative не завершён (нет [x] в $STATE)" >&2; ok=1; } ;;
      stage-3-dev)
        grep -q '^- \[x\] stage-2-audit' "$STATE" \
          || { echo "pipeline-state: BLOCKED stage-3: stage-2-audit не завершён" >&2; ok=1; }
        grep -Eq '^- constitution-gate: .*MUST-FLAG: 0($|[^0-9])' "$STATE" \
          || { echo "pipeline-state: BLOCKED stage-3: constitution-gate не записан или MUST-FLAG != 0" >&2; ok=1; }
        grep -Eq '^- user-approval: approved' "$STATE" \
          || { echo "pipeline-state: BLOCKED stage-3: user-approval != approved (гейт владельца обязателен)" >&2; ok=1; } ;;
      stage-4-quality)
        grep -q '^- \[x\] stage-3-dev' "$STATE" \
          || { echo "pipeline-state: BLOCKED stage-4: stage-3-dev не завершён" >&2; ok=1; }
        if grep -q '^## Units' "$STATE" && grep -q '^- \[ \] unit:' "$STATE"; then
          echo "pipeline-state: BLOCKED stage-4: не все юниты прошли convergence-check (unit-done):" >&2
          grep '^- \[ \] unit:' "$STATE" >&2; ok=1
        fi ;;
    esac
    if [ "$ok" -eq 0 ]; then note "check OK: $S можно стартовать"; fi
    exit "$ok"
    ;;

  status)
    need_state
    cat "$STATE"; echo
    next=""
    for s in $STAGES; do
      grep -q "^- \[x\] $s" "$STATE" || { next="$s"; break; }
    done
    if [ -z "$next" ]; then
      note "все этапы [x] — пайплайн завершён (итог: см. quality-verdict)"
    elif bash "$0" check "$DIR" "$next" >/dev/null 2>&1; then
      note "next: $next (check OK — стартуй с него)"
    else
      note "next: $next — BLOCKED:"
      bash "$0" check "$DIR" "$next" || true
    fi
    ;;

  *) die "неизвестная команда '$CMD'" ;;
esac
