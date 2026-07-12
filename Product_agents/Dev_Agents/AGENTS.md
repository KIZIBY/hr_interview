# HR Interview FDE Dev Agents Guide

Last updated: 2026-07-07 (bootstrap из LV_AGENT_TEAM upstream@fb73950; пайплайн: `Product_agents/ADAPTATION_PIPELINE.md`)

## Canonical Locations

- Каноны агентов: `Product_agents/Dev_Agents/`. Памяти — рядом; правила памяти: `Product_agents/MEMORY_CONVENTION.md`.
- Runtime-копии в `.claude/agents/<agent>.md` — **тонкие стабы** (frontmatter + «прочитай канон целиком»). Полнотекстовые копии ЗАПРЕЩЕНЫ (анти-дрейф). Поведение правится в каноне, tools/model — во frontmatter стаба.
- Публикации: `Product_agents/Dev_Agents/GIT_PUBLISH_RUNBOOK.md`. Баги: `docs/bug-handling-process.md` (+ `BUG_HUNTER_RULES.md`).
- Evidence: `docs/audit-evidence/<YYYY-MM-DD>/...` — сессионные артефакты в корень репо НЕ кладутся (`scripts/agent-preflight.sh` предупреждает).

## Team Status & Memory Index

| Agent | Profile (canon) | Memory | Status |
|---|---|---|---|
| kulibin | `Kulibin.md` | `memmory_Kulibin.md` | bootstrap (шаг 2 не завершён) |
| renata | `agent-renata.md` | `memmory_Renata.md` | bootstrap (шаг 2 не завершён) |
| semiglazka | `semiglazka.md` | `memmory_Semiglazka.md` | bootstrap (шаг 2 не завершён) |
| pushkin | `Pushkin.md` | `memmory_Pushkin.md` | bootstrap (шаг 2 не завершён) |

**Routing к 💤/неготовому агенту не выполняется молча** — явный wake или переадресация.

## Agent Routing

(заполнить на шаге 2 локализации: кто за что, границы, эскалации)
