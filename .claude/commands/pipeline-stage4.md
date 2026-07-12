---
description: "Stage 4 Quality Team: проверка реализации и вердикт для HRI. Usage: /pipeline-stage4 SPEC_DIR=specs/NNN-slug"
---

> 🔧 **ADAPTED FROM LV_AGENT_TEAM upstream@fb73950 (2026-07-07)** — механическая адаптация (шаг 1 пайплайна).
> TODO локализации (карта: `Product_agents/ADAPTATION_PIPELINE.md` §6): coverage taxonomy,
> доменные ловушки, маршрутизация, stop-list метки; ссылки на устав = TODO-CONSTITUTION.
> До прохождения шага 2 пайплайна этот канон — ЧЕРНОВИК.

# /pipeline-stage4 — Quality Team

**$ARGUMENTS**

Извлеки SPEC_DIR из аргументов (например `SPEC_DIR=specs/001-auth-module`).

Прочти `$SPEC_DIR/spec.md`, `$SPEC_DIR/plan.md`, `$SPEC_DIR/reviews/stage-2-audit.md`, `$SPEC_DIR/reviews/stage-3-dev.md`.

**State-гейт:** `bash scripts/pipeline-state.sh stage-start "$SPEC_DIR" stage-4-quality` (BLOCKED → сначала заверши stage-3).

---

## Ты — QA Director

**Spawni 4 субагентов параллельно:**

**Requirements Validator** (sonnet):
Прочти `$SPEC_DIR/spec.md`. Для КАЖДОГО функционального требования:
- Найди в коде file:line реализацию (across all services)
- Оцени статус: **DONE** / **PARTIAL** / **MISSING**
- Для PARTIAL/MISSING — объясни что конкретно отсутствует
- Проверь proto/NATS/migration consistency

Напиши `$SPEC_DIR/reviews/requirements-matrix.md`:
```
| # | Requirement | Status | Location | Notes |
|---|-------------|--------|----------|-------|
| 1 | ... | DONE | services/meeting-service/internal/handler/meeting.go:42 | |
```

**Test Engineer** (sonnet):
1. Запусти `go test ./services/{affected}... -v -short` (unit tests)
2. Если тестов нет для новой функциональности — напиши их
3. Для frontend: `npm test -- --watchAll=false`
4. Верни: количество тестов, результат, coverage
5. Запусти `go build ./...` и `go vet ./...` для всех сервисов

**Code Reviewer** (sonnet):
Проверь новый код против `$SPEC_DIR/reviews/stage-2-audit.md`:
- Все CRITICAL findings устранены?
- Все WARNING findings устранены или задокументированы?
- Go patterns: error wrapping, context, DI, no globals
- gRPC: proper status codes, proto validation
- NATS: durable consumers, ack, dead letter
- SQL: parameterized only, proper indexes
- Frontend: FSD, TypeScript strict, i18n, React Query
- Security: RBAC on every endpoint, no hardcoded secrets

**Technical Writer** (sonnet):
1. Обнови `CLAUDE.md` если добавились новые конвенции; новый сервис/критичная подсистема → создай/обнови `docs/runbooks/<service>.md` (конвенция: `Product_agents/OPERATIONS_GUIDE.md` §2 — как понять что сломалось, как перезапустить, известные грабли, зависимости)
2. **Learnings-консолидация (ритуал самообучения):** прочти `$SPEC_DIR/reviews/learnings.md` (все `## stage-N`); повторяющиеся Interpretations/Deviations — кандидаты в правила. Сформируй короткий список «предлагаю закрепить: <правило> → <куда: docs/pipeline-rules.md / CLAUDE.md / канон агента / доктрина>» — он попадёт в финальный вывод владельцу; **без одобрения владельца ничего не закрепляй** (кроме п.1 — бесспорных конвенций кода). Подтверждённые правила пайплайна append'ятся в `docs/pipeline-rules.md` (создай с заголовком при первом правиле; каждая запись: дата · источник specs/NNN · правило) — ПОСЛЕ конфликт-чека: не противоречит уставу и доктринам (bug-handling / SSO_AUTH_GUIDE / NFR_GUIDE); узкое правило только ужесточает широкое; конфликт → эскалация владельцу, не запись
3. Создай/обнови `CHANGELOG.md`:
   ```
   ## [Unreleased]
   ### Added
   - Feature: ...
   ### Services affected
   - meeting-service, voting-service, ...
   ```

---

## Вердикт

### PASS условия (все должны быть выполнены):
- [ ] Constitution Check (`docs/constitution-check.md`) против реализации: `MUST-FLAG: 0`
- [ ] Все requirements в матрице — DONE
- [ ] Нет CRITICAL в code review
- [ ] Все тесты проходят
- [ ] `go build ./...` без ошибок
- [ ] `go vet ./...` без ошибок
- [ ] Frontend: `npm run type-check && npm run lint` без ошибок

**При PASS:** запиши в state: `bash scripts/pipeline-state.sh verdict "$SPEC_DIR" PASS "N/N DONE, 0 CRITICAL"` + `bash scripts/pipeline-state.sh stage-done "$SPEC_DIR" stage-4-quality`. Финальный отчёт в `$SPEC_DIR/reviews/stage-4-quality.md`:
```
## Quality Gate: PASS
## Requirements Coverage: N/N DONE
## Tests: N passed
## Critical Issues: 0
## Services Verified: [list]
## Summary
```

### FAIL — retry < 2:
Запиши: `bash scripts/pipeline-state.sh verdict "$SPEC_DIR" FAIL "retry N: <краткая причина>"` (stage-4 в state остаётся `[-]`).
Создай список MISSING/PARTIAL + CRITICAL issues.
Запусти `/pipeline-stage3 SPEC_DIR=$SPEC_DIR` для исправлений.
После — повтори Stage 4 (retry + 1).

### FAIL — retry = 2:
Покажи requirements-matrix + нерешённые issues.
Спроси: **Доработать вручную / Принять как есть / Отменить?**

---

Выведи финальный статус: **PASS** или **FAIL** с резюме + список «предлагаю закрепить» из learnings-консолидации (закрепление — решение владельца).