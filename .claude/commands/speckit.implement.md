---
description: Execute implementation by processing tasks defined in tasks.md. Usage: /speckit.implement [SPEC_DIR]
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

1. **Find tasks**: Locate active spec in `specs/`. Load tasks.md, plan.md.

2. **Check checklists** (if `specs/NNN/checklists/` exists):
   - Count total/completed/incomplete items
   - If incomplete: ask user to proceed or stop

3. **Load implementation context**:
   - tasks.md: task list and execution plan
   - plan.md: tech stack, architecture, file structure
   - data-model.md: entities (if exists)
   - contracts/: API specs (if exists)

4. **Project setup**:
   - Verify/create .gitignore with Go patterns
   - Verify/create .dockerignore
   - Verify go.work structure

5. **Execute tasks phase-by-phase**:
   - Phase 1: Setup (project structure, dependencies)
   - Phase 2: Foundation (shared libs, proto, DB schemas)
   - Phase 3+: User stories (Proto → Migrations → Repo → Service → Handler → Frontend)
   - Final: Polish (tests, docs, Docker Compose)

6. **Implementation rules**:
   - Follow HRI conventions: Clean Architecture, pgx, gRPC, NATS
   - TDD when requested
   - Mark completed tasks as `[X]` in tasks.md
   - Halt on non-parallel task failure

7. **Completion validation**:
   - `go build ./...` for all services
   - `go vet ./...`
   - `go test ./... -short`
   - Frontend: `npm run type-check && npm run lint`
   - Report final status