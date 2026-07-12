---
description: "Stage 3 Dev Team: реализация фичи по plan.md для HRI. Usage: /pipeline-stage3 SPEC_DIR=specs/NNN-slug"
---

> 🔧 **ADAPTED FROM LV_AGENT_TEAM upstream@fb73950 (2026-07-07)** — механическая адаптация (шаг 1 пайплайна).
> TODO локализации (карта: `Product_agents/ADAPTATION_PIPELINE.md` §6): coverage taxonomy,
> доменные ловушки, маршрутизация, stop-list метки; ссылки на устав = TODO-CONSTITUTION.
> До прохождения шага 2 пайплайна этот канон — ЧЕРНОВИК.

# /pipeline-stage3 — Dev Team

**$ARGUMENTS**

Извлеки SPEC_DIR из аргументов (например `SPEC_DIR=specs/001-auth-module`).

Прочти `$SPEC_DIR/plan.md` и `$SPEC_DIR/reviews/stage-2-audit.md`.

**State-гейт (BLOCKING):** `bash scripts/pipeline-state.sh stage-start "$SPEC_DIR" stage-3-dev` — exit != 0 = **BLOCKED** (stage-2 не завершён / `MUST-FLAG != 0` / нет `user-approval: approved`). Остановись и покажи причину из вывода; обход или «догоняющее» одобрение задним числом запрещены. Если существует `docs/pipeline-rules.md` — прочти и передай субагентам как обязательные правила.

---

## Ты — Tech Lead

**RAG-дисциплина (spec 008): если у проекта есть `.context/cache.db` (индексирован LV_DCP) — перед чтением кода зови `lvdcp_pack(path=<корень>, query="<задача из plan.md>", mode="edit")` (пак-контракт из `CLAUDE.md`); передавай субагентам ранжированный срез вместо «прочитай всё вслепую». lvdcp-MCP недоступен или `coverage=ambiguous` → фолбэк на Grep/Glob, назови выбранный путь. Не проиндексирован (`.context/cache.db` нет — как сам mothership) → обычный Grep/Glob, дисциплина no-op.**

### STEP 0 — Inventory

Прочти все `.claude/agents/*.md`. Составь карту компетенций:
- `go-backend-developer` → services/*/internal/handler/, service/, repository/
- `db-expert` → services/*/migrations/, proto/, SQL
- `frontend-developer` → frontend/src/ (FSD + React + TypeScript)
- `ai-engineer` → services/ai-*/, LLM/Whisper/RAG
- `integration-engineer` → services/integration-*/, AD/SSO/SMTP/Calendar
- `test-runner` → services/*/internal/*_test.go, tests/
- `devops-deployer` → docker-compose*.yml, Dockerfile, Makefile
- `code-reviewer` → review only (Stage 4)

### STEP 1 — Gap Analysis

Для каждого требования из plan.md:
- Есть агент с нужной компетенцией → **AVAILABLE**
- Нет агента → **MISSING**

### STEP 2 — Hiring (при необходимости)

Для каждого MISSING создай `.claude/agents/{name}.md`:
```
---
name: {name}
description: {role}. Auto-created by pipeline for feature {NNN}.
tools: Read, Grep, Glob, Edit, Write
model: sonnet
---
You are a {spec} expert for HRI (Go microservices, gRPC, NATS, PostgreSQL).
## Constraints
- MUST comply with docs/constitution.md (инварианты I-1…I-16) — project supreme law
- Follow CLAUDE.md conventions
- Clean Architecture: handler → service → repository
- Parameterized SQL only ($1, $2 via pgx)
- context.Context as first argument
- Structured logging via zerolog
```

Запиши матрицу компетенций в `$SPEC_DIR/reviews/stage-3-dev.md`.

### STEP 3 — Task Breakdown

Базируйся на `## Units of Work` из plan.md (если секции нет — вся фича один юнит). Разбей юниты на атомарные задачи с file ownership:
- `go-backend-developer` → services/{name}/internal/handler/, service/, model/
- `db-expert` → services/{name}/migrations/, proto/ файлы
- `frontend-developer` → frontend/src/ (pages, widgets, features, entities)
- `ai-engineer` → services/ai-*/ полностью
- `integration-engineer` → services/integration-*/ полностью
- `devops-deployer` → docker-compose*.yml, Dockerfile

**Порядок**: Proto → Migrations → Repository → Service → Handler → Frontend

### STEP 4 — Spawn & Implement

Запусти 2-5 субагентов (последовательно для зависимых файлов, параллельно для независимых). Спавн логируй `bash scripts/pipeline-state.sh event "$SPEC_DIR" "agent:<имя>:start" "<юнит/задача>"`, финиш — `... event "$SPEC_DIR" "agent:<имя>:done" "<краткий summary>"` (однострочно, без `|` — таймлайн Flight Deck). Если среда вернула фактический расход субагента — запиши `bash scripts/pipeline-state.sh event "$SPEC_DIR" "usage:agent:<имя>" "tokens=<N> source=subagent-report"` (только реальные числа из отчёта среды; нет источника — не пиши, фабрикация запрещена).

**Worktree-per-unit (для НЕЗАВИСИМЫХ юнитов из plan.md — без depends-on друг на друга):**
- каждому параллельному юниту — свой worktree: `git worktree add .claude/worktrees/<unit> -b pipeline/NNN-<unit>`; файловые границы юнита из plan.md обязательны (пересечение границ = конфликт merge, разводи заранее);
- субагент работает только в своём worktree; общие контракты (proto/API/типы) фиксируются в plan.md ДО спавна, не изобретаются на лету;
- **merge последовательно** в рабочую ветку; после КАЖДОГО merge — convergence-check юнита в ОСНОВНОМ checkout (referee из STEP 5), только затем следующий merge;
- worktree удаляется ТОЛЬКО после `unit-done` + зелёного `bash scripts/agent-worktree-memory-check.sh` (агент мог писать память — data sacred);
- зависимые юниты — последовательно в основном checkout, без worktree-оверхеда.

Каждый субагент **обязан**:
- Следовать конвенциям из `CLAUDE.md`
- Parameterized SQL через pgx ($1, $2)
- context.Context как первый аргумент
- Ошибки через fmt.Errorf("context: %w", err)
- gRPC status codes (NotFound, InvalidArgument, etc.)
- NATS: durable consumers, msg.Ack()
- Frontend: FSD layers, React Query, TypeScript strict
- **Соответствовать `docs/constitution.md` (I-1…I-16) — верховный закон** (не хардкодь, читай файл): I-5 (`loadXForCaller`+RLS+404), I-11 (production-ready, ноль stub/TODO), I-14 (без инлайн-комментариев), I-15 (keyset+optimistic concurrency) и весь остальной свод
- Запустить `go vet` и `golangci-lint` на своих файлах

**Guardrails каждому субагенту (вставлять в промпт literal):**
- `DO NOT IMPLEMENT PLACEHOLDER OR SIMPLE IMPLEMENTATIONS` — полная реализация или явный отчёт «не смог, причина»; заглушка = провал юнита (I-11)
- `Before making changes search the codebase (don't assume an item is not implemented) using parallel subagents` — пустой одиночный grep не доказательство отсутствия
- Параллельность — только для чтения/поиска; build/test — строго один процесс за раз (back-pressure)
- Наверх возвращай ТОЛЬКО summary-результат (что сделано, файлы, статус check'а) — не транскрипт и не листинги

**IMPORTANT:** Устрани ВСЕ CRITICAL findings из `$SPEC_DIR/reviews/stage-2-audit.md`.

### STEP 5 — Integration + referee юнитов

После всех субагентов:
1. Проверь конфликты между файлами
2. Запусти `go build ./...` для всех затронутых сервисов
3. Запусти `go vet ./...`
4. Для frontend: `npm run type-check && npm run lint`
5. **Referee-сверка юнитов (zero-trust):** для каждого юнита из plan.md прогони его convergence-check **сам** — «готово» от субагента не evidence. Check зелёный → `bash scripts/pipeline-state.sh unit-done "$SPEC_DIR" <unit>`; красный → юнит возвращается субагенту, unit-done НЕ ставится.
6. Обнови `$SPEC_DIR/reviews/stage-3-dev.md` с результатами

---

**State:** `bash scripts/pipeline-state.sh stage-done "$SPEC_DIR" stage-3-dev` (только после зелёных build/vet/type-check и unit-done по каждому юниту).

**Learnings:** допиши `$SPEC_DIR/reviews/learnings.md` (`## stage-3`): Interpretations / Deviations / Tradeoffs / Open questions — только непустые.

Выведи пользователю:
1. Список реализованных задач
2. Список созданных/изменённых файлов по сервисам
3. Результат build + lint
4. Готов к Stage 4? Запусти: `/pipeline-stage4 SPEC_DIR=$SPEC_DIR`