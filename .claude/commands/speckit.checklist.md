---
description: Generate a requirements quality checklist for the current feature. Usage: /speckit.checklist [domain]
---

> 🔧 **ADAPTED FROM LV_AGENT_TEAM upstream@fb73950 (2026-07-07)** — механическая адаптация (шаг 1 пайплайна).
> TODO локализации (карта: `Product_agents/ADAPTATION_PIPELINE.md` §6): coverage taxonomy,
> доменные ловушки, маршрутизация, stop-list метки; ссылки на устав = TODO-CONSTITUTION.
> До прохождения шага 2 пайплайна этот канон — ЧЕРНОВИК.

## Checklist Purpose: "Unit Tests for English"

Checklists validate the quality, clarity, and completeness of REQUIREMENTS — not implementation.

- ✅ "Are visual hierarchy requirements defined for all card types?" (completeness)
- ✅ "Is 'prominent display' quantified with specific sizing/positioning?" (clarity)
- ❌ NOT "Verify the button clicks correctly" (that tests implementation)

## User Input

```text
$ARGUMENTS
```

## Execution Steps

1. **Find spec**: Locate active spec in `specs/`. Load spec.md, plan.md (if exists), tasks.md (if exists).

2. **Clarify intent**: Derive up to 3 questions about checklist focus, depth, audience.

3. **Generate checklist**:
   - Create `specs/NNN/checklists/{domain}.md` (e.g., `security.md`, `ux.md`, `api.md`)
   - Items numbered CHK001, CHK002...
   - Group by quality dimension:
     - Requirement Completeness
     - Requirement Clarity
     - Requirement Consistency
     - Acceptance Criteria Quality
     - Scenario Coverage
     - Edge Case Coverage
     - Non-Functional Requirements

4. **Item format**:
   ```
   - [ ] CHK001 - Are [requirement type] defined/specified for [scenario]? [Quality Dimension, Spec §FR-N]
   ```

5. **Report**: file path, item count, focus areas.

## Prohibited patterns (testing implementation, not requirements):
- ❌ "Verify", "Test", "Confirm" + implementation behavior
- ❌ "Displays correctly", "works properly"
- ✅ "Are requirements defined/specified/documented for..."
- ✅ "Is [vague term] quantified with specific criteria?"