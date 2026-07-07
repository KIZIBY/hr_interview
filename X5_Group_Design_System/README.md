# X5 Strategy Design System

A design system for **strategic and analytical presentations** produced by X5 Group's strategy function — internal pitches to top management, technology committees, and cross-functional analyses.

> **Scope.** This system is for the strategy function only. It is **not** for: annual reports, investor relations, marketing/OOH, or any operating-unit B2C branding (Pyaterochka, Перекрёсток, Чижик).

---

## 1 · Brand & Product Context

X5 Group is Russia's largest foodtech company. Its public brand essence is **«Главные в еде»** ("Leaders in food"), and the parent visual identity is built around a signature 3D ribbon graphic called **«Ландшафт роста X5»** (X5 Growth Landscape).

For strategy decks, however, that consumer-facing brand is **dialled back**. The strategy aesthetic is restrained, executive-grade, and analytical:

- The dominant text colour is **dark navy `#303145`**, not the consumer-facing green.
- Branded graphic elements (ribbons, 3D illustrations) are **optional**, not mandatory.
- Layouts are dense with diagrams, KPI tiles, customer journeys, and dual-column comparisons rather than hero photography.

The brand character — visionary, reliable, energetic, human — is expressed through clean typography (X5 Sans), generous whitespace, and confident sentence-case titles. Imagery, when used, is photographic or schematic, never decorative-for-its-own-sake.

### Sources used to build this system

| Priority | Source | Used for |
|---|---|---|
| 1 | `uploads/DESIGN.md` (canonical) | All decisions; this README defers to it on every conflict. |
| 2 | `uploads/X5Sans-*.{ttf,woff,woff2,eot}` | Font files — sole source of truth for typography. |
| 3 | `uploads/X5_brandbook.pdf` v2.1 | Formal brand standard (see DESIGN.md §1, §6, §7). |
| 4 | `uploads/Template.pptx` | Master layout names (`3_light`, `1_light`, …) and base placeholders. |
| 5 | `uploads/Template_PPTX final result example.pptx` | 18 fully-built example slides → typography sizes, accent colours, badge geometry, content patterns. |

The Figma export folder referenced in DESIGN.md (`/02_figma_export/`) was **not provided**, so colour tokens fall back to brandbook hex values rather than Figma variables.

---

## 2 · Content Fundamentals (Tone & Voice)

X5's strategy decks are written in **Russian**, with English technical terms (`AI-commerce`, `customer journey`, `D2C`, `B2B`) accepted unaltered when they are the working vocabulary of the audience. Tone is **factual, restrained, and confident** — closer to a McKinsey strategy memo than to consumer marketing copy.

### Voice axes (from brandbook §1)

1. **Human & simple** — no bureaucratic stock phrases, no jargon-for-jargon's-sake. Short sentences. Warm, but never chatty.
2. **Vivid & resonant** — modern Russian; emotional resonance without populism; moderate anglicisms accepted in B2B/tech contexts.
3. **Uplifting & positive** — every message should leave a positive trace.
4. **Confident & honest** — backed by numbers; mistakes are named, not glossed over.

### Casing & punctuation — strategy decks specifically

- **Sentence case** for all titles. Only the first word and proper nouns are capitalised. _"Боли клиентов и поставщиков"_ — never _"Боли Клиентов И Поставщиков"._
- **No exclamation marks** in strategy titles.
- **No imperative verbs** ("Купи!", "Узнай!") — that is marketing register, not strategy.
- **Em-dash `—`** for "X as Y" constructions and parenthetical clauses; never the hyphen `-` for that role.
- **No hanging prepositions** at line ends (no _висячие предлоги_) — line breaks should produce a "clean flag" shape.
- **Heading length:** ≤ 3 lines for headings, ≤ 2 lines for subheadings (3 rare, 4 exceptional).
- **English term left-as-is** when it is the working term: _Customer journey_, _Supplier journey_, _AI-commerce_, _D2C-канал_, _shoppable_ — not transliterated.

### Title patterns observed in the sample deck

| Pattern | Example |
|---|---|
| Noun phrase, descriptive | "AI-агент как единая точка покупок" |
| Direct topic label | "Боли клиентов", "Приложение" |
| Present-tense statement | "Клиентский опыт сейчас" |
| Strategic hypothesis | "Создаём agentic-commerce платформу для покупок в бизнесах Х5 и не только" |
| English-term section | "Customer journey", "Supplier journey" |

### Things to avoid

- **No emoji.** None. The brand never uses them in strategy decks.
- **No marketing punch lines** like "Меняем правила игры!" or "Будущее уже здесь" — use specific claims grounded in numbers instead.
- **No "we/мы" cheerleading** — prefer agentless or third-person framing in titles.
- **No filler sections** — every slide earns its place. If there's nothing to say, cut the slide.

---

## 3 · Visual Foundations

### 3.1 Colour

The strategy palette is **a dark-navy/white ground with restrained green and blue accents**. The consumer-facing X5 green never dominates a strategy slide — it appears in the logo, occasional accent fills, and the optional Growth-Landscape graphic.

- **Text:** `#303145` (the navy-violet "ink" used everywhere) on white, `#FFFFFF` on dark fills.
- **Brand greens:** `#5FAF2D` (logo leaf), `#0F5A05` (Травяной — primary brand green), `#05320A` (depth).
- **Diagram accents (from sample deck):** `#6CA4C3` blue, `#94BBD1` blue-soft, `#B378D3` violet, `#AAC936` citrus, with their `Soft` tints `#F5DCFF`, `#EBF2D0`, `#EFEFF0`. Used sparingly on diagrams and grouping rectangles.
- **Status:** `#1E8737` / `#5FAF2D` (success), `#F5A000` (warn), `#E52825` / `#F23024` (danger).
- **Surfaces:** white, `#F3F8FA` (faint blue-white), `#EFEFF0` (neutral oval — slide 2), `#F2F2F2` (alt grey).

> **Conflict applied.** The brandbook says `#0F5A05` is "the main text colour on layouts." Both PPTX files use `#303145`. We follow the PPTX (DESIGN.md §2.3) for strategy decks. Green is reserved for marketing/OOH.

### 3.2 Typography

- **Family:** X5 Sans (Regular + Medium only — no Bold, no Light).
- **Headings:** Medium, 83–87% line-height, −2% tracking. Maximum 3 lines.
- **Body:** Regular, ~1.45 line-height.
- **Sentence case** everywhere. No all-caps display except for tiny eyebrow labels.
- **Em-dash —** is the system separator (titles, captions, breadcrumbs).

Sizes observed in the sample deck (PPTX pt → CSS px on 1280px slide):

| Role | pt | px-ish | Weight |
|---|---|---|---|
| Title-slide H1 | 72 pt | ≈ 96 px | Medium |
| Slide title | ~36–40 pt | ≈ 48–56 px | Medium |
| Section header | ~28 pt | ≈ 36 px | Medium |
| Sub-header | ~20–24 pt | ≈ 26–30 px | Medium |
| Body | 12–14 pt | 16–18 px | Regular |
| Caption / label | 10–12 pt | 13–16 px | Regular or Medium |
| Eyebrow / breadcrumb | 8–10 pt | 11–13 px | Medium |

### 3.3 Layout

- **Slide size:** 33.87 × 19.05 cm (16:9). At screen render, target **1280 × 720** for the design canvas; scale up for actual presentation.
- **Margin:** ≈ 1.1 cm on all sides — equal to logo clearspace (= ½ logo height). Set as `--slide-margin: 44px` on a 1280px canvas.
- **Logo:** **bottom-left**, always 0° rotation. Never top-right, never centre. With slogan, slogan goes bottom-right; minimum gap = 1 logo width.
- **Grid:** No rigid column system documented. Layouts use **free placement within the safe area** — most slides feel like a single content area with intentional whitespace, not a 12-col grid. Two-column layouts (`2_light`) split roughly 50/50.

### 3.4 Backgrounds & textures

- **White is the default.** ~80% of slides are flat white.
- **The Growth-Landscape ribbon** (3D ribbed graphic in `#05320A` / `#0F5A05` / `#9BC30F`) is the brand hero — but it is **optional in strategy decks**. Reserve for title slides, section dividers, or one or two decorative moments. Never blur or soften it.
- **Soft radial gradients** in green or violet (from sample deck) appear behind the title slide as a low-contrast atmospheric wash. Use sparingly.
- **No repeating patterns, no grain, no vignettes.** The aesthetic is clean and analytical.
- **No full-bleed marketing photography in strategy decks.** Photos appear as small, framed inline elements only when supporting a specific argument.

### 3.5 Imagery

- **Photography:** vivid, appetising, natural — when used. But strategy decks lean **diagram-heavy**, not photo-heavy.
- **3D objects** (toys/clay aesthetic, never hyperreal) and **3D plants** are part of the brand kit but are **not typical** in strategy decks.
- **Diagrams**: rectangles with hairline strokes or soft pastel fills (`#EFEFF0`, `#F5DCFF`, `#EBF2D0`); arrows in `#303145`; stage labels in Medium 12–14 pt.
- Color vibe of imagery — **warm-cool balanced, never cold or moody**. No b&w, no heavy grain.

### 3.6 Cards & containers

- **Cards** are mostly **flat fills** with no shadow, separated from the white ground by a soft tint (e.g. `#EFEFF0`) or a hairline `#DFE7EC` border.
- **Corner radius** is restrained: `8px` for small chips, `16px` for cards, `999px` (pill) for date badges and status pills. No 24px+ "playful" radii.
- **Shadows** are used sparingly and softly: `0 1px 2px rgba(48,49,69,.06), 0 8px 24px rgba(48,49,69,.08)` for floating cards. No glows, no neon, no inner shadow.

### 3.7 Borders & strokes

- Hairline `#DFE7EC` for in-content dividers.
- Stronger `#C4C6CE` for table cells and form fields.
- Stroke weight 1 px at 1280 canvas. Scale with the slide.
- **No coloured left-border accent cards** — that is an AI-slop trope; this brand uses fills, badges, or icons instead.

### 3.8 Interaction states (for UI / clickable prototypes)

- **Hover:** background lifts to a 4% darker tint of the surface (or 4% lighter on dark surfaces). For text links: opacity 0.8.
- **Press:** scale 0.98, no colour shift.
- **Focus:** 2 px solid `#303145` ring offset 2 px. On dark fills, 2 px `#FFFFFF` ring.
- **Disabled:** opacity 0.4. Never grey the text out; reduce the alpha.

### 3.9 Motion

- **Purpose:** clarify, never decorate. Slide transitions in deck mode = simple cross-fade or push.
- **Easing:** `cubic-bezier(.2, 0, 0, 1)` standard, `cubic-bezier(.3, 0, 0, 1)` emphasised.
- **Duration:** 120 ms (micro), 200 ms (default), 320 ms (slow / emphatic). Nothing longer than 400 ms.
- **No bounces, no springs, no parallax** in strategy materials.

### 3.10 Transparency & blur

- **Blur is forbidden on the Growth-Landscape graphic** (brandbook §7.2).
- Otherwise, use blur only for modal backdrops (`backdrop-filter: blur(12px)` over a 60–80% white scrim).
- Transparency: prefer flat fills. If you tint, use opacity 0.06 / 0.10 / 0.14 stops.

---

## 4 · Iconography

X5 has its own brand icon library, but the icon files are **not present** in this project's uploads. The following rules describe the brand's intended approach plus our **substitution policy** for working without them.

### 4.1 X5 brand icons (intended)

- **Style:** Solid / filled, monochrome dark green (`#0F5A05`) on light, or `#FFFFFF` on dark fills.
- **Construction:** grid-based with an inner-padded safe area; icons drawn within the padded zone.
- **Categories** documented in the brandbook: **People (люди)**, **Food (еда)**, plus more not captured in our upload.
- In strategy context they appear as small inline glyphs in process diagrams, KPI tiles, and customer-journey stages.

### 4.2 Substitution policy (we use this until the brand pack arrives)

Because the official X5 icon set is not available, this design system **substitutes Lucide** (https://lucide.dev) for general-purpose UI iconography when building prototypes and deck content. Lucide's stroke-based aesthetic is **the closest CDN-available match** to the brandbook's geometric style — but it is *stroked*, while the X5 originals are *filled*. **Flag any usage of Lucide in design output as a substitution**, and replace with the official X5 icon set as soon as it is provided.

CDN reference (no install required):

```html
<script src="https://unpkg.com/lucide@latest"></script>
<i data-lucide="check-circle"></i>
<script>lucide.createIcons();</script>
```

For inline usage in JSX, prefer `lucide-react`:

```jsx
import { CheckCircle } from "https://esm.sh/lucide-react@0.460";
<CheckCircle size={18} strokeWidth={1.5} color="#0F5A05" />
```

### 4.3 Other glyph rules

- **No emoji** in strategy decks. Period.
- **Unicode arrows / dashes** are fine and encouraged: `→`, `←`, `—`, `·`, `№`, `±`, `≈`. They are part of the typographic register.
- **Numerals as graphics:** large numerical figures (e.g. "2 000", "3 500+") used as KPI displays — set in X5 Sans Medium at 4×–8× body size. The brandbook also references custom 3D numerals; these are not part of the strategy-deck kit.

---

## 5 · Index of files

| Path | What it is |
|---|---|
| `README.md` | This file. |
| `SKILL.md` | Cross-compatible Agent Skill front-matter; tells an agent how to use this system. |
| `colors_and_type.css` | All design tokens (CSS custom properties) and base typography rules. **Import this first.** |
| `fonts/X5Sans-*.{woff2,woff,ttf}` | X5 Sans Regular & Medium — bundled. |
| `assets/logos/x5-logo-color.svg` | Color logo: leaf `#5FAF2D` + "X5" `#000000`. Default for white/light backgrounds. |
| `assets/logos/x5-logo-dark.svg` | Monochrome dark navy `#303145` (matches strategy text colour). |
| `assets/logos/x5-logo-green.svg` | Monochrome dark-green `#0F5A05` for green-tinted layouts. |
| `assets/logos/x5-logo-white.svg` | All-white inverse for dark backgrounds. |
| `assets/logos/x5-logo-dark.png` | PNG fallback of the dark logo. |
| `assets/from_sample_deck/` | Decorative gradients & textures extracted from the example deck — title-slide background washes. |
| `preview/*.html` | Per-card preview tiles populating the Design System tab. |
| `slides/index.html` | Live HTML deck of sample slide templates (Title, Section, 1-Column, 2-Column, Statement, KPI). |
| `slides/*.jsx` | Reusable slide components. |
| `_extracted/` | Source PPTX slide XML kept for reference. |
| `uploads/` | Raw user-supplied source files (DESIGN.md, fonts, brandbook, PPTX). |

### Slide templates available (`slides/`)

Mirroring the PPTX master layouts (DESIGN.md §5):

- **TitleSlide** (`3_light`) — title + date badge + author bar.
- **SectionDivider** (`light`) — large section label, mostly white.
- **ContentSlide** (`1_light`) — single-column workhorse layout.
- **TwoColumnSlide** (`2_light`) — comparison / parallel arguments.
- **StatementSlide** (`11_light`) — single big strategic claim.
- **KPISlide** (`5_light` / `12_light`) — large numerical figure(s).

---

*Last updated: 2026-04-25.*
