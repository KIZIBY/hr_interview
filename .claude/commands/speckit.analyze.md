---
description: Perform cross-artifact consistency and quality analysis across spec.md, plan.md, and tasks.md. READ-ONLY.
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

## Goal

Identify inconsistencies, duplications, ambiguities, and underspecified items across `spec.md`, `plan.md`, `tasks.md` before implementation. READ-ONLY — no file modifications.

## Execution Steps

1. **Find artifacts**: Locate active spec in `specs/`. Load spec.md, plan.md, tasks.md. Прогони детерминированные линты и включи их вывод в отчёт: `bash scripts/spec-lint.sh "$SPEC_DIR"` + `bash scripts/plan-lint.sh "$SPEC_DIR"` (traceability FR/NFR → plan).

2. **Build semantic models**:
   - Requirements inventory from spec.md
   - Task coverage mapping from tasks.md
   - Architecture decisions from plan.md

3. **Detection passes** (max 50 findings):
   - **Duplication**: near-duplicate requirements
   - **Ambiguity**: vague terms without metrics (fast, scalable, robust)
   - **Underspecification**: requirements without tasks, tasks without file paths
   - **Coverage gaps**: requirements with zero tasks, orphan tasks
   - **Inconsistency**: terminology drift, conflicting decisions, missing NATS topics in plan vs tasks
   - **Cross-service**: service referenced in plan but no tasks for it

4. **Severity**: CRITICAL / HIGH / MEDIUM / LOW

5. **Output report** (Markdown, no file writes):

```
## Specification Analysis Report

| ID | Category | Severity | Location(s) | Summary | Recommendation |
|----|----------|----------|-------------|---------|----------------|

## Coverage Summary
| Requirement Key | Has Task? | Task IDs | Notes |

## Metrics
- Total Requirements / Tasks / Coverage %
- Ambiguity / Duplication / Critical counts

## Next Actions
[Specific command suggestions]
```

6. **Offer remediation**: Ask if user wants suggested edits (don't apply automatically).