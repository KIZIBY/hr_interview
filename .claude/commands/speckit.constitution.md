---
description: Create or update the project constitution with core development principles. Usage: /speckit.constitution [principles]
handoffs:
  - label: Build Specification
    agent: speckit.specify
    prompt: Implement the feature specification based on the updated constitution.
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

Manage the project constitution at `docs/constitution.md`. This file defines non-negotiable development principles.

1. **Load existing constitution** (or create from template if missing: у нового проекта устава нет → создай из `docs/constitution.template.md` — универсальные инварианты + доменные слоты `[ЗАПОЛНИ]`).

2. **Если канонический устав уже существует** — `docs/constitution.md` (в reference-инстансе X5: v1.3.0, **16 инвариантов I-1…I-16**, модель apex+ссылки, процедура поправок + журнал). **Загружай и правь ЕГО**, не регенерируй с нуля. Принципы ниже — исторический черновик (6 шт.), уже поглощённый инвариантами; источником НЕ использовать:

   > _Historical draft (superseded by I-1…I-16):_ On-Premise Data Sovereignty · Clean Architecture · API Compatibility · Security by Default · Graceful Degradation · Enterprise-Grade Reliability.

   При правке соблюдай процедуру поправок (Часть III): изменение инварианта + bump версии + запись в журнал; молчаливый обход запрещён. Сверка enforcement — `docs/constitution-check.md`.

3. **Collect/derive values** from user input or existing docs.

4. **Validate**: No vague language, all principles testable, MUST/SHOULD explicit.

5. **Write** to `docs/constitution.md`.

6. **Report**: version, principles, suggested next command.