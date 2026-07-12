---
description: Create or update a feature specification from a natural language description. Usage: /speckit.specify "описание фичи"
handoffs:
  - label: Build Technical Plan
    agent: speckit.plan
    prompt: Create a plan for the spec. I am building with Go microservices...
  - label: Clarify Spec Requirements
    agent: speckit.clarify
    prompt: Clarify specification requirements
    send: true
---

> 🔧 **ADAPTED FROM LV_AGENT_TEAM upstream@fb73950 (2026-07-07)** — механическая адаптация (шаг 1 пайплайна).
> TODO локализации (карта: `Product_agents/ADAPTATION_PIPELINE.md` §6): coverage taxonomy,
> доменные ловушки, маршрутизация, stop-list метки; ссылки на устав = TODO-CONSTITUTION.
> До прохождения шага 2 пайплайна этот канон — ЧЕРНОВИК.

## User Input

```text
$ARGUMENTS
```

You **MUST** consider the user input before proceeding (if not empty).

## Outline

The text the user typed after `/speckit.specify` is the feature description.

1. **Generate a concise short name** (2-4 words) for the feature:
   - Action-noun format (e.g., "voting-module", "ai-transcription", "rbac-system")
   - Preserve technical terms

2. **Determine feature number**:
   - Count existing directories in `specs/`
   - Use next number: NNN (001, 002, ...)
   - Create: `specs/NNN-<slug>/` and `specs/NNN-<slug>/checklists/`
   - Set SPEC_FILE = `specs/NNN-<slug>/spec.md`

3. **Parse the feature description**:
   - Extract: actors, actions, data entities, constraints
   - Map to HRI microservices architecture
   - Identify which services are affected

4. **Write spec.md** following this structure:

```markdown
# Feature: [Name]

> Источник: тикет <KEY>   <!-- необязательная строка (spec 002 FR-17/18): если фича пришла из
> тикета — укажи ключ (BOARD-123 / #456) и свяжи прогон: pipeline-state.sh link-ticket <SPEC_DIR> <KEY>;
> spec-lint предупредит о рассинхроне маркера со state.md. Фича без тикета — строку удалить. -->

## Overview
[1-2 paragraphs describing the feature and its business value]

## User Stories
- As a [role], I want [action] so that [benefit]

## Functional Requirements
FR-001: [Testable requirement]
FR-002: ...

## Non-Functional Requirements
[Доктрина: Product_agents/NFR_GUIDE.md — 5 категорий (performance / scalability / reliability /
observability / security), КАЖДЫЙ NFR квантифицирован: метрика — целевое значение — метод
измерения — условия. «Быстро/надёжно/безопасно» без числа запрещены. Неприменимая категория —
явное N/A. Security-вход/роли — в секции Authentication & Access, не здесь.]
NFR-001 (performance): [метрика — цель — как мерить — при какой нагрузке]

## Authentication & Access
[ОБЯЗАТЕЛЬНАЯ секция, доктрина: Product_agents/SSO_AUTH_GUIDE.md §3. Если фича затрагивает
вход/пользователей/роли/доступ: способ входа (по умолчанию корпоративный SSO {{SSO_PROVIDER}});
источник ролей — группы каталога → маппинг (напр. {{SSO_ADMIN_GROUP}} → admin); logout/сессии/
ревокация при деактивации; тест-доступ для QA. Если НЕ затрагивает — одна строка:
"N/A (не затрагивает вход/роли/доступ)".]

## Affected Services
- [service-name]: [what changes]

## Data Entities
- [Entity]: [fields, relationships]

## Edge Cases
- [scenario]: [expected behavior]

## Out of Scope
- [what is NOT included]

## Assumptions
- [documented assumptions]

## Success Criteria
- [measurable outcome]
```

5. **Specification Quality Validation**:
   - Create `specs/NNN-<slug>/checklists/requirements.md` with quality checks
   - Validate: no implementation details, testable requirements, measurable success criteria
   - Max 3 [NEEDS CLARIFICATION] markers for critical decisions only
   - If clarifications needed, present as multiple-choice questions
   - **Детерминированные гейты:** `bash scripts/pipeline-state.sh init "$SPEC_DIR" "<фича>"` (state.md + audit.md — speckit лёгкий трек: этапные чекбоксы/гейты /pipeline им не проходятся, но аудит-след и resume работают) + `bash scripts/spec-lint.sh "$SPEC_DIR"` — FAIL → дополни spec.md до выхода

6. **Report**: Output spec file path, readiness status, suggest `/speckit.clarify` or `/speckit.plan` next.

## Guidelines
- Focus on **WHAT** users need and **WHY**
- Avoid HOW (no tech stack, APIs, code structure in spec)
- Written for business stakeholders, not developers
- Every requirement must be testable
- **Auth by default**: если у продукта есть пользовательский вход — стандарт входа корпоративный
  SSO ({{SSO_PROVIDER}}, см. `Product_agents/SSO_AUTH_GUIDE.md`); самодельный логин — только
  явным решением владельца, зафиксированным в Authentication & Access + Assumptions