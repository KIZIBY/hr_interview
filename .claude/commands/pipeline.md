---
description: "Полный 4-этапный пайплайн разработки фичи HRI: Creative → Audit → [USER APPROVAL] → Dev → Quality. Usage: /pipeline \"описание фичи\""
---

> 🔧 **ADAPTED FROM LV_AGENT_TEAM upstream@fb73950 (2026-07-07)** — механическая адаптация (шаг 1 пайплайна).
> TODO локализации (карта: `Product_agents/ADAPTATION_PIPELINE.md` §6): coverage taxonomy,
> доменные ловушки, маршрутизация, stop-list метки; ссылки на устав = TODO-CONSTITUTION.
> До прохождения шага 2 пайплайна этот канон — ЧЕРНОВИК.

> **SYSTEM NOTE FOR THE MODEL:** This is a self-contained execution prompt. Do NOT invoke the Skill tool before executing — there is no "pipeline" skill to invoke. Execute the stages described below directly using the Agent tool to spawn subagents. Proceed immediately to "Подготовка".

# /pipeline — Feature Development Pipeline (HRI)

Feature: **$ARGUMENTS**

---

## Подготовка

0. **Scope** (из `SCOPE=` в аргументах; по умолчанию `feature`):
   - `bugfix` → **/pipeline не запускается**: баг идёт по `docs/bug-handling-process.md` (intake §1 → systematic-debugging → fix → DoD §8) — маршрутизируй туда и остановись; 4 этапа для бага это overhead.
   - `feature` → стандартный прогон (ниже).
   - `enterprise` → как feature, но строже: NFR по всем 5 категориям `NFR_GUIDE.md` (N/A — только решением владельца), `Units of Work` в plan.md обязательны, в stage-4 requirements-matrix без PARTIAL.
0.5. **Intent-brief для эпиков.** Если фича — эпик (описание тянет на несколько спек, «платформа/раздел/модуль целиком», или scope=enterprise с широкой формулировкой) — ДО stage-1 напиши `specs/NNN-<slug>/intent.md`: проблема и кому болит · зачем сейчас · границы (что НЕ делаем) · критерий успеха (измеримый) · декомпозиция на под-фичи (каждая = свой прогон пайплайна). Покажи владельцу, получи подтверждение декомпозиции — и гони под-фичи по одной. Эпик одним прогоном не делается.
1. Определи номер NNN: посмотри сколько директорий уже есть в `specs/` и возьми следующий номер (001, 002, ...)
2. Создай директорию `specs/NNN-<slug>/reviews/` где slug = транслитерация первых 3-4 слов фичи
3. Запомни путь `SPEC_DIR=specs/NNN-<slug>`
4. **State + resume:** `bash scripts/pipeline-state.sh init "$SPEC_DIR" "<фича>" <scope>`. Если `state.md` уже существует — скрипт печатает статус и `next:` — это **resume**: продолжи с указанного этапа, НЕ начинай с нуля и НЕ создавай новый SPEC_DIR.

---

## State-машина и гейты (детерминированные — обязательно)

Каждый этап оборачивается вызовами `scripts/pipeline-state.sh` (ведёт `$SPEC_DIR/state.md` + append-only `$SPEC_DIR/audit.md`):

- **перед этапом**: `bash scripts/pipeline-state.sh stage-start "$SPEC_DIR" <stage>` — внутри выполняется `check`; exit != 0 = этап **BLOCKED** (причина в выводе). Остановись и покажи причину — обход гейта запрещён.
- **после этапа**: `bash scripts/pipeline-state.sh stage-done "$SPEC_DIR" <stage>`.
- **stage-1**: перед `stage-done` прогони `bash scripts/spec-lint.sh "$SPEC_DIR"` — FAIL → дополни spec.md.
- **stage-2**: итог Constitution Check запиши: `... gate "$SPEC_DIR" "MUST-FLAG: N · SHOULD-FLAG: N · NEEDS-INFO: N"`; ответ владельца: `... approve "$SPEC_DIR" <approved|revise|abort>`.
- **stage-4**: вердикт: `... verdict "$SPEC_DIR" <PASS|FAIL> "<детали>"`.
- **units** (если plan.md выделяет Units of Work): `... units-set "$SPEC_DIR" "u1,u2"` в stage-2; `... unit-done "$SPEC_DIR" <u>` в stage-3 ТОЛЬКО после своего прогона convergence-check юнита — stage-4 заблокирован, пока все юниты не done.
- **trace-события**: при спавне субагента — `... event "$SPEC_DIR" "agent:<имя>:start" "<задача>"`, по завершении — `... event "$SPEC_DIR" "agent:<имя>:done" "<краткий summary>"` (символ `|` в аргументы не передавать). Из событий Flight Deck (`bash scripts/pipeline-dashboard.sh`) строит таймлайн с длительностями; дашборд перегенерируется в любой момент, источник — state.md/audit.md.
- **learnings** (ритуал самообучения): в конце КАЖДОГО этапа допиши `$SPEC_DIR/reviews/learnings.md`, секция `## stage-N`: Interpretations (что трактовал сам) / Deviations (где отступил от инструкции и почему) / Tradeoffs / Open questions — только непустые пункты. В stage-4 Technical Writer консолидирует и предлагает владельцу, что закрепить.
- **правила проекта (слоистая модель)**: подтверждённые владельцем правила пайплайна живут в `docs/pipeline-rules.md` (project-слой; каждая запись — дата + источник specs/NNN). Приоритет: **устав > доктрины mothership (bug-handling / SSO_AUTH_GUIDE / NFR_GUIDE) > pipeline-rules > сырые learnings**. Перед записью нового правила — конфликт-чек: узкое правило может только ужесточать/конкретизировать широкое, НЕ ослаблять; противоречит уставу → не записывается, эскалация владельцу (versioned-поправка устава). Все этапы читают `docs/pipeline-rules.md` при старте, если файл существует.

`<stage>` = `stage-1-creative` | `stage-2-audit` | `stage-3-dev` | `stage-4-quality`. stage-3 механически не стартует без `user-approval: approved` и `MUST-FLAG: 0` в state.md.

---

## STAGE 1: Creative Team

Ты — Creative Director (Opus). Запусти 4 субагента (Sonnet) параллельно:

1. **Brainstormer**: 3-5 user stories и альтернативных подходов. Go микросервисы, gRPC, NATS, PostgreSQL, React.
2. **Critical Analyst**: риски, edge cases, cross-service dependencies, AI availability, enterprise integration issues.
3. **System Analyst** (`.claude/agents/system-analyst.md`): влияние на существующие сервисы, proto changes, NATS topics, DB migrations.
4. **Hard Critic** (`.claude/agents/hard-critic.md`): минимум 5 оспариваний, YAGNI, over-engineering для 400 совещаний/год.

**Output:**
- `$SPEC_DIR/spec.md` — спецификация (WHAT/WHY; фича трогает вход/роли/доступ → обязательная секция `## Authentication & Access` по `Product_agents/SSO_AUTH_GUIDE.md` §3, иначе явное «N/A»)
- `$SPEC_DIR/reviews/stage-1-creative.md` — консолидированный отчёт

---

## STAGE 2: Audit Team

Ты — Audit Director (Opus). Запусти 5 субагентов (Sonnet) параллельно:

1. **Security Reviewer**: SQL injection, RBAC, JWT, SSO/Authentication & Access ({{SSO_PROVIDER}}, инварианты `Product_agents/SSO_AUTH_GUIDE.md` §4), gRPC auth, file upload, audit logging
2. **Performance Analyst**: N+1 queries, gRPC chains, NATS backpressure, Redis caching, WebSocket limits
3. **Architecture Reviewer**: Clean Architecture, service boundaries, proto compatibility, NATS naming
4. **AI Reviewer**: on-premise only, RBAC in RAG, prompt injection, timeouts, graceful degradation
5. **Frontend Reviewer**: FSD layers, TypeScript strict, i18n, React Query, accessibility
6. **Constitution Gate** (связывающий): сверка спеки с `docs/constitution.md` (I-1…I-16) по процедуре `docs/constitution-check.md`; любой `MUST-FLAG` блокирует переход к stage-3

**Output:**
- `$SPEC_DIR/plan.md` — технический план
- `$SPEC_DIR/reviews/stage-2-audit.md` — отчёт аудита

---

## USER APPROVAL GATE (manual — НЕ продолжай пока пользователь не ответит)

Покажи:
1. `plan.md` content
2. `CRITICAL: N | WARNING: N | INFO: N`
3. Все CRITICAL findings
4. **Constitution Check:** `MUST-FLAG: N` (Approve разрешён только при `MUST-FLAG: 0`)

Спроси: **Approve / Revise / Abort?**

---

## STAGE 3: Development Team

Ты — Tech Lead (Opus). 5-step process:

1. **Inventory**: прочти `.claude/agents/*.md`, составь карту
2. **Gap Analysis**: план → какие компетенции нужны → AVAILABLE / MISSING
3. **Hiring**: создай недостающих агентов в `.claude/agents/`
4. **Spawn & Implement**: 2-5 субагентов с file ownership, порядок: Proto → Migrations → Repo → Service → Handler → Frontend
5. **Integration**: `go build ./...`, `go vet ./...`, frontend lint

**Output:**
- Рабочий код
- `$SPEC_DIR/reviews/stage-3-dev.md` — решения и trade-offs

---

## STAGE 4: Quality Team

Ты — QA Director (Opus). Запусти 4 субагента:

1. **Requirements Validator** (Sonnet): матрица spec.md ↔ код
2. **Test Engineer** (Sonnet): go test, frontend test, coverage
3. **Code Reviewer** (Sonnet): audit findings addressed, Go/gRPC/NATS patterns
4. **Technical Writer** (Sonnet): CLAUDE.md, CHANGELOG.md

### Retry Logic:
- **PASS**: all DONE + no CRITICAL + tests passing + build ok
- **FAIL + retry < 2**: narrow scope Dev Team → retry Quality
- **FAIL + retry = 2**: show user → manual decision

**Output:**
- `$SPEC_DIR/reviews/stage-4-quality.md`
- `$SPEC_DIR/reviews/requirements-matrix.md`
- Вердикт: **PASS** / **FAIL**