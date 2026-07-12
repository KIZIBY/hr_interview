---
name: pipeline
description: 4-stage feature development pipeline for HRI. Runs Creative → Audit → Dev → Quality stages with adversarial review. Use /pipeline command to start.
---

> 🔧 **ADAPTED FROM LV_AGENT_TEAM upstream@fb73950 (2026-07-07)** — механическая адаптация (шаг 1 пайплайна).
> TODO локализации (карта: `Product_agents/ADAPTATION_PIPELINE.md` §6): coverage taxonomy,
> доменные ловушки, маршрутизация, stop-list метки; ссылки на устав = TODO-CONSTITUTION.
> До прохождения шага 2 пайплайна этот канон — ЧЕРНОВИК.

# /pipeline Feature Development Pipeline (HRI)

## Usage

```
/pipeline "описание фичи"
```

## Requires

Agent Teams enabled: `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1` in `.claude/settings.json`

## Overview

```
/pipeline "описание фичи"
    │
    Stage 1: Creative Team ────→ spec.md + stage-1-creative.md
    │
    Stage 2: Audit Team ───────→ plan.md + stage-2-audit.md
    │         ┌─ USER APPROVAL ─┐
    │         │ (показывает план)│
    │         └─────────────────┘
    │
    Stage 3: Dev Team ─────────→ рабочий код + stage-3-dev.md
    │   ▲
    │   │ retry (max 2) + список доработок
    │   │
    Stage 4: Quality Team ─────→ requirements-matrix.md + stage-4-quality.md
                                  вердикт: PASS / FAIL

    FAIL + retry < 2  → назад в Stage 3
    FAIL + retry = 2  → спрашивает user
    PASS              → финальный отчёт + готовый feature branch
```

## Artifacts

```
specs/NNN-feature-name/
├── spec.md                        # Stage 1: что строим (WHAT/WHY)
├── plan.md                        # Stage 2: как строим (HOW)
├── state.md                       # State-машина: чекбоксы этапов + гейты (ведёт pipeline-state.sh)
├── audit.md                       # Append-only журнал событий пайплайна (кто/когда/что решил)
├── data-model.md                  # Stage 2: entities
├── tasks.md                       # Stage 3: task breakdown
├── research.md                    # Stage 2: technology decisions
├── contracts/                     # Stage 2: API specs
└── reviews/
    ├── stage-1-creative.md        # Creative Team отчёт
    ├── stage-2-audit.md           # Audit findings
    ├── stage-3-dev.md             # Dev decisions + competency matrix
    ├── stage-4-quality.md         # QA вердикт
    └── requirements-matrix.md     # Requirement ↔ code mapping
```

## State-машина и детерминированные гейты

`scripts/pipeline-state.sh` ведёт `state.md`/`audit.md` per SPEC_DIR: `stage-start` (внутри `check` — exit != 0 = BLOCKED), `stage-done`, `gate` (итог Constitution Check), `approve` (ответ владельца; `approved` невозможен без `MUST-FLAG: 0`), `units-set`/`unit-done` (юниты из plan.md; stage-4 заблокирован, пока каждый юнит не прошёл свой convergence-check), `verdict` (PASS/FAIL), `status` (сводка + `next:`). **stage-3 механически не стартует** без `user-approval: approved` + `MUST-FLAG: 0` — гейт не зависит от дисциплины промпта. `scripts/spec-lint.sh` — линт структуры spec.md (REQUIRED-секции, вкл. `Authentication & Access`; пустая auth-секция и >3 `NEEDS CLARIFICATION` = FAIL; NFR без чисел = warn) — зовётся в конце stage-1 и на входе stage-2. `scripts/plan-lint.sh` — линт plan.md + **traceability**: каждый FR/NFR из spec.md обязан иметь след в plan.md/tasks.md (осиротевшее требование = FAIL) — зовётся в stage-2 перед USER APPROVAL.

**Scope** (`SCOPE=` при запуске, хранится в state.md): `feature` (default) · `enterprise` (NFR все 5 категорий `NFR_GUIDE.md`, Units обязательны, matrix без PARTIAL) · `bugfix` (в /pipeline НЕ заходит — маршрут в `docs/bug-handling-process.md`).

**Learnings ritual**: каждый этап дописывает `reviews/learnings.md` (Interpretations / Deviations / Tradeoffs / Open questions); stage-4 Technical Writer консолидирует и предлагает владельцу, что закрепить в CLAUDE.md/канонах — закрепление только с одобрения владельца.

**Flight Deck (визуализация)**: `bash scripts/pipeline-dashboard.sh` → `docs/pipeline-dashboard.html` — статический per-run trace-дашборд из `specs/*/state.md + audit.md`: обзор прогонов, этапы/гейты/юниты, таймлайн событий с длительностями (`X:start`→`X:done`). Субагенты логируются через `pipeline-state.sh event` (семантика совместима с OTel GenAI: `agent:*` ≈ invoke_agent). Если среда вернула фактический расход субагента — запиши `bash scripts/pipeline-state.sh event "$SPEC_DIR" "usage:agent:<имя>" "tokens=<N> source=subagent-report"` (только реальные числа из отчёта среды; нет источника — не пиши, фабрикация запрещена). Никаких демонов — перегенерируй в любой момент.

## Stage 1: Creative Team
- **Lead**: Creative Director (Opus)
- **Teammates**: Brainstormer, Critical Analyst, system-analyst, hard-critic (all Sonnet)
- **Gate**: Automatic → Stage 2

## Stage 2: Audit Team
- **Lead**: Audit Director (Opus)
- **Teammates**: Security Reviewer, Performance Analyst, Architecture Reviewer, AI Reviewer, Frontend Reviewer (all Sonnet)
- **Gate**: USER APPROVAL — shows plan.md + findings, asks Approve / Revise / Abort

## Stage 3: Dev Team
- **Lead**: Tech Lead (Opus)
- **Adaptive composition** from `.claude/agents/`:
  - go-backend-developer, db-expert, frontend-developer, ai-engineer, integration-engineer, test-runner, devops-deployer
  - Auto-hires missing agents
- **Order**: Proto → Migrations → Repository → Service → Handler → Frontend
- **Gate**: Automatic → Stage 4

## Stage 4: Quality Team
- **Lead**: QA Director (Opus)
- **Teammates**: Requirements Validator, Test Engineer, code-reviewer, Technical Writer (Sonnet)
- **Retry**: FAIL + retry < 2 → narrow Dev Team → retry Quality

## Agent Inventory (HRI)

| Agent | Specialization | Files |
|-------|---------------|-------|
| go-backend-developer | Go services, gRPC, NATS, business logic | services/*/internal/ |
| db-expert | PostgreSQL, pgvector, goose migrations | services/*/migrations/, SQL |
| frontend-developer | React, TypeScript, FSD, Ant Design | frontend/src/ |
| ai-engineer | vLLM, Whisper, RAG, embeddings | services/ai-*/ |
| integration-engineer | AD/LDAP, SSO, Exchange, SMTP | services/integration-*/ |
| test-runner | Go tests, testcontainers, Playwright | *_test.go, tests/ |
| code-reviewer | Quality, security, patterns | review only |
| system-analyst | Architecture impact analysis | analysis only |
| hard-critic | Devil's advocate, YAGNI | challenge only |
| devops-deployer | Docker Compose, Traefik, monitoring | docker-compose*.yml |

## Cost Estimate

| Stage    | Teammates       | ~Cost  |
|----------|-----------------|--------|
| Creative | 4 + Opus lead   | $4-6   |
| Audit    | 5 + Opus lead   | $5-7   |
| Dev      | 2-5 + Opus lead | $5-10  |
| Quality  | 4 + Opus lead   | $3-5   |
| **Total**|                 | **~$17-28** |

## Error Handling
- Teammate crashed: Lead spawns replacement after 5 min idle
- Stage crashed / сессия прервана: **resume по state.md** — `bash scripts/pipeline-state.sh status specs/NNN-slug` печатает `next:` (первый незакрытый этап + причина, если BLOCKED); `/pipeline` с существующим SPEC_DIR продолжает оттуда, не начиная с нуля
- Agent Teams unavailable: fallback to regular subagents

## Individual Stage Commands
- `/pipeline-stage1 "feature" SPEC_DIR=specs/NNN-slug`
- `/pipeline-stage2 SPEC_DIR=specs/NNN-slug`
- `/pipeline-stage3 SPEC_DIR=specs/NNN-slug`
- `/pipeline-stage4 SPEC_DIR=specs/NNN-slug`

## Speckit Integration
For lighter-weight spec workflow (without adversarial teams):
- `/speckit.specify "feature"` → spec.md
- `/speckit.clarify` → refine spec
- `/speckit.plan` → plan.md
- `/speckit.tasks` → tasks.md
- `/speckit.analyze` → consistency check
- `/speckit.checklist [domain]` → requirements quality
- `/speckit.implement` → execute tasks
- `/speckit.constitution` → project principles
- `/speckit.taskstoissues` → GitHub issues