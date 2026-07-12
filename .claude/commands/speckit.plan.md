---
description: Generate technical implementation plan from feature spec. Usage: /speckit.plan [SPEC_DIR]
handoffs:
  - label: Create Tasks
    agent: speckit.tasks
    prompt: Break the plan into tasks
    send: true
  - label: Create Checklist
    agent: speckit.checklist
    prompt: Create a checklist for the following domain...
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

1. **Find spec**: Locate active spec directory in `specs/` (or from arguments). Load `spec.md`.

2. **Load context**: Read `spec.md` and any existing `checklists/requirements.md`.

3. **Phase 0 — Research**:
   - Extract unknowns from spec
   - Research best practices for each technology decision
   - Write `specs/NNN/research.md` with: Decision, Rationale, Alternatives

4. **Phase 1 — Design**:
   - Extract entities → `specs/NNN/data-model.md`
   - Map to PostgreSQL schemas (schema-per-service)
   - Generate API contracts: REST endpoints, gRPC services, NATS topics
   - Write to `specs/NNN/contracts/`

5. **Write plan.md** (после записи — `bash scripts/plan-lint.sh "$SPEC_DIR"`: FAIL = нет REQUIRED-секций или осиротевшие FR/NFR из spec.md — адресуй каждое или перенеси в Out of Scope):

```markdown
# Implementation Plan: [Feature]

## Technical Context
- Go microservices, gRPC, NATS JetStream, PostgreSQL
- React + TypeScript frontend (FSD)
- Docker Compose deployment

## Architecture Decisions
[Key decisions from research]

## Services Affected
| Service | Changes | New Files | Migrations |
|---------|---------|-----------|------------|

## Implementation Phases
### Phase 1: [Foundation]
### Phase 2: [Core logic]
### Phase 3: [Integration]
### Phase 4: [Frontend]
### Phase 5: [Testing & polish]

## Proto Changes
[New/modified .proto files]

## DB Migrations
[Per-service migration files]

## NATS Topics
[New topics]

## API Endpoints
[New REST endpoints in api-gateway]

## Known Risks
[Risks from spec + research]

## Dependencies
[External: AD/LDAP, SSO, Exchange, etc.]
```

6. **Report**: plan file path, artifacts generated, suggest `/speckit.tasks`.

## Key Rules
- Use absolute paths
- Map every requirement to implementation
- Identify cross-service dependencies