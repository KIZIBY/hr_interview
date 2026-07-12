---
description: Convert tasks from tasks.md into GitHub issues. Usage: /speckit.taskstoissues [SPEC_DIR]
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

1. **Find tasks**: Locate active spec in `specs/`. Load tasks.md.

2. **Check Git remote**:
```bash
git config --get remote.origin.url
```

> ONLY PROCEED IF THE REMOTE IS A GITHUB URL

3. **For each task**: Create a GitHub issue using `gh issue create`:
   - Title: Task description
   - Body: file paths, dependencies, acceptance criteria
   - Labels: phase, service name, priority
   - Milestone: feature name (create if needed)

> NEVER CREATE ISSUES IN REPOSITORIES THAT DON'T MATCH THE REMOTE URL