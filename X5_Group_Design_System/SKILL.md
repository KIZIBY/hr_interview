---
name: x5-strategy-design
description: Use this skill to generate well-branded interfaces and assets for X5 Group's strategy function — internal strategic and analytical presentations, throwaway prototypes, and design mocks. Contains essential design guidelines, colors, type, fonts, assets, and slide templates for prototyping. Scope is internal strategy decks only — not for marketing, IR, annual reports, or operating-unit B2C brands (Pyaterochka / Перекрёсток / Чижик).
user-invocable: true
---

Read the README.md file within this skill, and explore the other available files. The canonical source of truth is the `DESIGN.md` extract that produced this system; defer to it on any conflict.

If creating visual artifacts (slides, mocks, throwaway prototypes, etc), copy assets out of `assets/` and `fonts/`, import `colors_and_type.css`, and produce static HTML files for the user to view. Examples of finished slide templates live in `slides/` (title, section, content, two-column, statement, KPI). If working on production code, copy assets and read the rules in this skill to become an expert in designing with this brand.

If the user invokes this skill without any other guidance, ask them what they want to build or design (strategy deck? single slide? KPI dashboard? throwaway prototype?), ask 5–10 focused questions about audience and content, and act as an expert designer who outputs HTML artifacts _or_ production code, depending on the need.

**Hard rules — never violate:**
- Font: X5 Sans Regular / Medium only. No Bold, no Light, no system substitutes.
- Body text colour: `#303145` (ink), not the brandbook's grass green.
- Logo: bottom-left, 0° rotation, never recoloured.
- No emoji, no exclamation marks, no imperatives in titles.
- Sentence case + em-dash `—` always.
