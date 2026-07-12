---
description: "Stage 1 Creative Team: генерация spec.md для фичи HRI. Usage: /pipeline-stage1 \"описание фичи\" SPEC_DIR=specs/NNN-slug"
---

> 🔧 **ADAPTED FROM LV_AGENT_TEAM upstream@fb73950 (2026-07-07)** — механическая адаптация (шаг 1 пайплайна).
> TODO локализации (карта: `Product_agents/ADAPTATION_PIPELINE.md` §6): coverage taxonomy,
> доменные ловушки, маршрутизация, stop-list метки; ссылки на устав = TODO-CONSTITUTION.
> До прохождения шага 2 пайплайна этот канон — ЧЕРНОВИК.

# /pipeline-stage1 — Creative Team

Feature: **$ARGUMENTS**

Извлеки из аргументов: описание фичи и SPEC_DIR (например `SPEC_DIR=specs/001-auth-module`).
Если SPEC_DIR не указан — определи номер NNN сам: посмотри сколько директорий в `specs/` и возьми следующий. Slug = транслитерация первых 3-4 слов.

Создай директорию `$SPEC_DIR/reviews/`.

**State:** `bash scripts/pipeline-state.sh init "$SPEC_DIR" "<фича>"` (state уже есть → это resume: смотри `next:` в статусе), затем `bash scripts/pipeline-state.sh stage-start "$SPEC_DIR" stage-1-creative`.

---

## Ты — Creative Director

Прочти `CLAUDE.md` для контекста проекта. Прочти список существующих specs в `specs/`. Если существует `docs/pipeline-rules.md` — прочти: это подтверждённые владельцем правила пайплайна (project-слой), они обязательны.

Прочти `docs/constitution.md` (Часть I, инварианты I-1…I-16) — спека должна быть совместима с инвариантами **уже на этапе авторинга** (дешевле, чем падать на Constitution Gate в stage-2). В `spec.md` явно отметь, какие инварианты затрагивает фича.

Если фича затрагивает **вход, пользователей, роли или доступ** — прочти `Product_agents/SSO_AUTH_GUIDE.md`: стандарт входа — корпоративный SSO ({{SSO_PROVIDER}}); spec.md обязан содержать секцию `## Authentication & Access` (способ входа, группы каталога → роли, сессии/logout/ревокация, тест-доступ для QA). Не затрагивает — секция «N/A» одной строкой.

**NFR — по доктрине `Product_agents/NFR_GUIDE.md`:** 5 категорий (performance / scalability / reliability / observability / security), каждый NFR квантифицирован (метрика — цель — метод — нагрузка), «быстро/надёжно» без числа запрещены, неприменимая категория — явное N/A. Hard Critic обязан оспорить завышенные цели (YAGNI: продукт на сотни совещаний в год, не миллионы).

**Spawni 4 субагентов параллельно:**

**Brainstormer** (sonnet): Сгенерируй 3-5 user stories и альтернативных подходов к реализации фичи для проекта HR Interview FDE (стек: Static HTML/CSS/JS, client-side only (no backend); X5 Group Design System; BroadcastChannel/localStorage sync). Для каждого подхода: плюсы, минусы, сложность. Учитывай конвенции стека из CLAUDE.md проекта (reference X5: gRPC между сервисами, NATS JetStream для событий, PostgreSQL schema-per-service, React + TypeScript фронтенд). Верни структурированный список.

**Critical Analyst** (sonnet): Найди слабые места, риски и скрытые зависимости. Проверь: cross-service consistency, gRPC breaking changes, NATS message ordering, PostgreSQL schema migration risks, RBAC gaps, AI service availability, enterprise integration edge cases (AD/LDAP timeout, SSO token expiry, Exchange sync conflicts). Верни список рисков с severity (CRITICAL/WARNING/INFO).

**System Analyst** (sonnet): **RAG-дисциплина (spec 008): если у проекта есть `.context/cache.db` (индексирован LV_DCP) — начни с `lvdcp_pack(path=<корень>, query="<влияние фичи на сервисы>", mode="navigate")` вместо слепого Glob/Read; пак вернёт ранжированный срез релевантных файлов/символов, экономит контекст. lvdcp-MCP недоступен или пак `coverage=ambiguous` → фолбэк на Glob/Read, назови выбранный путь в отчёте (NFR-3).** Затем/иначе прочти структуру `services/` и `proto/` (Glob, Read). Проанализируй влияние фичи на существующие микросервисы. Карта: какие сервисы затронуты, нужны ли новые .proto файлы, новые NATS topics, миграции БД, изменения в API Gateway routing. Data flow diagram.

**Hard Critic** (sonnet): Оспорь КАЖДЫЙ возможный вывод. Минимум 5 вызовов: почему отдельный микросервис а не модуль? нужно ли в MVP? можно ли решить конфигурацией? будет ли это работать при 400 совещаниях/год (не миллионах)? какие допущения не проверены? Предлагай конкретные упрощения.

---

## Синтез и вывод

Синтезируй все ответы субагентов. Напиши два файла:

**`$SPEC_DIR/spec.md`**:
```
## Overview
## User Stories
## Functional Requirements (нумерованный список)
## Non-Functional Requirements
## Authentication & Access (обязательна; SSO_AUTH_GUIDE.md §3 — или явное «N/A»)
## Out of Scope
## Affected Services (список затронутых микросервисов)
```

**`$SPEC_DIR/reviews/stage-1-creative.md`**:
```
## Brainstorm Findings
## Critical Analysis
## System Impact Analysis
## Challenged Assumptions (from Hard Critic)
## Synthesis & Final Spec Decisions
```

---

**Гейт этапа (детерминированный):** `bash scripts/spec-lint.sh "$SPEC_DIR"` — FAIL → дополни spec.md (секции — контракт stage-2), повтори линт. Затем `bash scripts/pipeline-state.sh stage-done "$SPEC_DIR" stage-1-creative`.

**Learnings:** допиши `$SPEC_DIR/reviews/learnings.md` (`## stage-1`): Interpretations / Deviations / Tradeoffs / Open questions — только непустые.

Выведи пользователю:
1. Краткое резюме spec.md (Overview + User Stories)
2. Топ-3 риска из Critical Analyst
3. Топ-3 вызова от Hard Critic
4. Готов к Stage 2? Запусти: `/pipeline-stage2 SPEC_DIR=$SPEC_DIR`