---
description: Generate actionable, dependency-ordered tasks.md from plan. Usage: /speckit.tasks [SPEC_DIR]
handoffs:
  - label: Analyze For Consistency
    agent: speckit.analyze
    prompt: Run a project analysis for consistency
    send: true
  - label: Implement Project
    agent: speckit.implement
    prompt: Start the implementation in phases
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

1. **Find plan**: Locate active spec in `specs/` (or from arguments). Load `plan.md` and `spec.md`.

2. **Load design docs**: Also load if exist: `data-model.md`, `contracts/`, `research.md`.

3. **Generate tasks** organized by user story priority:

### Checklist Format (REQUIRED)
```
- [ ] [TaskID] [P?] [Story?] Description with file path
```
- `- [ ]` checkbox always
- `T001, T002...` sequential IDs
- `[P]` if parallelizable
- `[US1], [US2]...` for user story phases
- Clear file paths

### Phase Structure
- **Phase 1**: Setup (project init, go.work, proto setup)
- **Phase 2**: Foundation (shared libs, DB schemas, proto generation)
- **Phase 3+**: User Stories in priority order
  - Within each: Proto → Migrations → Repository → Service → Handler → Frontend
- **Final Phase**: Polish (tests, docs, Docker Compose updates)

4. **Write tasks.md** to `specs/NNN/tasks.md`.

5. **Report**: total tasks, per-phase counts, parallel opportunities, MVP scope.

## Task Rules
- Each task specific enough for an LLM to complete without extra context
- File paths required for every code task
- Service name prefix for cross-service awareness
- Proto → Migrations → Repo → Service → Handler ordering within each story