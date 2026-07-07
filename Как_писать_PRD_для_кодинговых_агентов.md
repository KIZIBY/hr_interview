# Как писать PRD для кодинговых агентов, чтобы UI получился с первого раза

*апрель 2026 · 25-30 минут чтения*

---

Полтора месяца назад я отдал Claude Code довольно детальный PRD. Стандартная история: Stream → Epic → User Story в формате «Как [роль], я хочу [действие], чтобы [ценность]» → пять-семь Acceptance Criteria в чекбоксах. Я писал такие PRD годами, по этому формату у меня выкачены десятки фич, и мне казалось, что для AI-агента этого должно быть более чем достаточно.

Через 20 минут я смотрел на собранный экран и понимал, что это не то.

Не то по многим причинам. Не было skeleton при загрузке — вместо него моргал пустой блок. Кнопка «Сохранить» становилась активной слишком рано, ещё до того, как обязательные поля валидны. На мобиле форма ехала за края экрана. При ошибке сети ничего не происходило — просто кнопка крутилась и крутилась. Inline-ошибка под полем email появлялась мгновенно при первом же символе, а не на blur, как я хотел. Empty state на dashboard после регистрации — вообще нашёл там какой-то AI-сгенерированный stock-текст в стиле «Welcome to your journey».

Я начал ругать модель. А потом перечитал свой PRD.

И увидел то, что должен был увидеть давно: в моих Acceptance Criteria буквально написано «пользователь может зарегистрироваться через email». Вот и всё. Ни состояний, ни валидаций, ни мобилки, ни ошибок, ни пустых экранов. Я отдал агенту 1200 слов про бизнес-контекст, JTBD, гипотезу, Backbone, фазы — и **0 слов про то, как должен выглядеть и вести себя интерфейс**.

Это была не проблема Claude. Это была проблема в том, что я писал PRD как для живого фронтендера и дизайнера, у которых есть профессиональный контекст. Они бы заполнили эти дыры из опыта. Агент — нет.

Этот пост — про то, что я нашёл, пока пытался разобраться, как **по-человечески писать UI-секцию PRD под кодингового агента**. Не отказываясь от User Story и AC, не переходя на Figma-only, не нанимая отдельного «дизайнера для AI». Просто разобраться, что индустрия выработала за последние полтора года и как это встроить в существующий формат.

Спойлер: индустрия выработала довольно много. И всё это укладывается в один **UI-блок под Acceptance Criteria** с очень понятной анатомией.

---

## Почему классические User Story + AC ломаются на UI

Сначала про корень проблемы, иначе остальное будет просто чек-лист.

User Story в виде «Как [роль], я хочу [действие], чтобы [ценность]» — это **продуктовый жанр**. Он оптимизирован под бизнес-стейкхолдера, который читает документ и должен понять, что за фича и зачем. Acceptance Criteria — это функциональная проверка: галочки «работает / не работает». Этого достаточно, когда между PRD и кодом сидит человек, который **сам додумывает интерфейс из своего опыта**.

Кодинговый агент так не умеет. Не потому что он тупой — потому что он работает иначе.

Addy Osmani, который ведёт engineering в Google Chrome, сформулировал это лучше всех:

> «Если вы недоспецифицировали задачу, ИИ сделает что-то неожиданное. Если переспецифицировали — проще написать код самому».

Между этими двумя крайностями и лежит вся работа по написанию PRD под агента. У классической User Story проблема в том, что она структурно **застряла на первой стороне**: она оптимизирована под максимальную абстракцию. Что хорошо для бизнес-обсуждения — ровно то же плохо для кода.

Конкретно три механизма ломаются на UI:

**Первое.** AC проверяет «что», но не описывает «как выглядит». «Пользователь может зарегистрироваться» — это true/false. А что должно быть на экране? Какие состояния? Как ведёт себя кнопка? Что при ошибке? — всё это в стандартном AC отсутствует.

**Второе.** Ambiguity → plausible code. Augment Code в апрельском гайде по AI-спекам приводит каноничный пример: спека пишет «validate the payment input and return an error if invalid» — модель сгенерирует функцию, возвращающую boolean или throwing exception. Без структурированного объекта ошибки, без error codes по полям, без обработки случая, когда невалидны несколько полей сразу. Код **правдоподобный**, но контракт неправильный — и вы это заметите, только когда UI попытается показать, какое именно поле сломано.

То же самое в UI везде. «Кнопка отправки disabled, пока форма не валидна» — а когда форма становится валидной? После каждой буквы или после blur? А при ошибке — обводка красным, текст под полем, иконка, всё сразу? Без явного ответа агент решит сам. И его решение будет статистически плотным под средний опыт его training data — то есть очень среднее.

**Третье.** Уровень абстракции User Story — продуктовый, а агенту нужен **поведенческий**. Это разные жанры документа. User Story не отменяется (она продолжает быть отличной для бизнеса). Просто под неё нужно дописать слой, на котором агент работает.

Этот слой и есть тема статьи.

---

## Что вообще сложилось в 2026

Прежде чем нырять в конкретные приёмы, короткий ландшафт. Я не буду подробно — кому надо, ссылки в конце, — но без этого не понять контекст.

К весне 2026 в индустрии есть устойчивая практика **spec-driven development (SDD)**: разработка ведётся не от кода, а от спецификации, и спецификация передаётся агенту как «ground truth». Три флагмана:

- **AWS Kiro** — отдельный VS Code-based IDE, в котором каждая фича = три md-файла: `requirements.md` (User Stories + Acceptance Criteria в нотации EARS, об этом дальше), `design.md` (архитектура и sequence diagrams), `tasks.md` (атомарные задачи).
- **GitHub Spec Kit** — open-source CLI, бутстрапит spec-driven воркфлоу под Claude Code, Cursor, Copilot, Gemini CLI и др. Получил 72k звёзд за полгода.
- **Tessl** — самая радикальная позиция: spec — это источник кода, код регенерируется. Идея «specs as the new source code».

И поверх этого — Augment Code, Thoughtworks, Anthropic с их `frontend-design` skill, Bolt с гайдом по prompting'у — все говорят примерно одно и то же. Спека — это **слоёный документ**. Не один формат, а четыре-пять разных слоёв, каждый отвечает за свой аспект:

- **Intent** — Markdown, бизнес-контекст («зачем»).
- **Requirements** — Markdown с EARS-предложениями («что система делает»).
- **Interfaces** — OpenAPI/YAML («контракты»).
- **Acceptance** — Gherkin или таблицы input/output («как проверить»).
- **Contracts** — JSON Schema / Zod / TypeScript («точные типы»).

Для PRD-секции про UI ключевые слои — **Requirements (EARS)**, **Acceptance (Gherkin или нумерованные AC)** и **Contracts** (типы props, design tokens). Дальше я разбираю каждый практический фреймворк, который есть смысл встроить в существующий PRD.

---

## EARS — самая дешёвая вакцина против двусмысленности

Если бы у меня был выбор сделать только одно изменение в PRD под агента — это был бы EARS.

EARS (Easy Approach to Requirements Syntax) — придумал Alistair Mavin в Rolls-Royce в 2009 году для авиастроения. Чисто инженерная штука: натуральный язык требований страдает восемью болезнями (двусмысленность, многословность, дублирование и т.д.), и большинство из них лечится **пятью строгими шаблонами предложений**. Цитирование оригинальной статьи — 481, и для safety-critical это годами стандарт.

В 2026 EARS вышел из авиа и медицины в мейнстрим — именно благодаря spec-driven development. Kiro прямо встроил EARS как обязательный формат AC. У Spec Kit есть открытое предложение (Issue #1356) встроить EARS в `spec-template.md`. Логика простая: EARS-шаблоны заставляют автора быть **explicit про триггеры, условия и состояния** — а это ровно то, что агенту нужно для генерации детерминированного кода.

Пять шаблонов:

| Тип | Шаблон | UI-пример |
|---|---|---|
| Ubiquitous (всегда) | The system shall [action] | The system shall display the user's avatar in the top-right corner of every authenticated screen. |
| Event-Driven | When [trigger], the system shall [action] | When the user clicks Save, the system shall persist the form and show a green toast «Saved» for 2 seconds. |
| State-Driven | While [state], the system shall [action] | While the form is submitting, the system shall disable the submit button and show a spinner inside it. |
| Unwanted Behavior | If [condition], then the system shall [action] | If the email field is empty when the user clicks Submit, then the system shall show inline error «Email is required» and focus the field. |
| Optional | Where [feature is enabled], the system shall [action] | Where dark mode is enabled, the system shall use the `--bg-dark-1` token for the page background. |

И есть **Complex** — комбинация:

> When the user submits the registration form, **if** the email already exists in the database, **then** the system shall show an inline error «Account exists» with a link «Sign in instead» under the email field.

Что мне понравилось, когда я начал переписывать AC в EARS:

1. **Триггеры стали явными.** Раньше я писал «пользователь видит ошибку» — теперь обязан написать **когда** он её видит. На blur поля? После клика Submit? Сразу при mount?
2. **Состояния стали явными.** «While submitting» — это уже компонентное состояние, агент сразу понимает, что нужно его моделировать.
3. **Edge cases вылезают наружу.** Когда я начинаю писать Unwanted Behavior, я физически не могу пропустить кейс «если сеть отключилась».

Минус EARS — **многословно**. Каждое требование отдельной строкой. Для экрана с 30 микро-поведениями получаете 30 строк. И EARS не показывает структуру — это не визуал, это поведение. То есть он один не закрывает UI-секцию, ему нужны соседи.

Самое полезное правило, которое я для себя вывел: **в Acceptance Criteria переписывайте всё в EARS-стиль**. Это даже не отдельная секция — это просто переформулировка существующих AC. Стоит 0 рублей дополнительной работы и режет половину уточняющих вопросов агента.

Сравните:

```
❌ Пользователь может зарегистрироваться через email.
✅ When the user submits the form with valid data, the system shall create 
   an account within 2 seconds and redirect to /onboarding.

❌ Кнопка отправки активна, когда форма заполнена.
✅ When all required fields are valid AND ToS is checked, the system shall 
   enable the Submit button.

❌ При ошибке показывается сообщение.
✅ If submission fails with status 409, then the system shall show inline 
   error «Account exists» under the email field with link «Sign in instead».
```

Это то же самое — но агент читает второй вариант как **граф состояний и переходов**, а первый как «что-то про регистрацию».

---

## Gherkin — когда EARS мало

Given-When-Then придумал Daniel Terhorst-North в 2003 в рамках BDD. Gherkin — DSL, который читается людьми и парсится Cucumber'ом. Шаблон знаком всем, кто работал с тестами:

```gherkin
Feature: Forgot password

  Scenario: User requests password reset
    Given the user is on the login page
    When the user clicks "Forgot password"
    And enters a valid email
    Then the system shall send a recovery link
    And display "Check your email" message

  Scenario: Invalid email format
    Given the user is on the "Forgot password" page
    When the user enters "notanemail"
    Then the input field shows error "Please enter a valid email"
    And the "Send link" button stays disabled
```

Gherkin сильнее EARS по двум вещам:

- **Сценарий = пользовательский путь по экрану.** Это естественно ложится на «состояния + переходы», и читается как живой пользовательский тест.
- **Исполняемость.** Cucumber/Behave/SpecFlow превращают эти .feature-файлы в реальные UI-тесты. Это уже не просто документация, это бесплатные e2e.

Где Gherkin проигрывает EARS — **в краткости**. Каждый Scenario это 5-10 строк, и для нумерованных AC внутри User Story это слишком развесисто.

Мой практический вывод: **EARS внутри User Story** (как нумерованные AC), **Gherkin** — отдельным `.feature`-файлом или дополнительной секцией к крупным флоу, особенно где планируем e2e-автоматизацию. То, как делает Kiro: внутри `requirements.md` AC пишутся в стиле «WHEN ... THE SYSTEM SHALL ...» — это EARS, переписанный в Gherkin-tone. И для большинства задач этого достаточно.

---

## Screen specs и обязательные четыре состояния

Здесь начинается интересное. Если EARS — про поведение, то screen spec — про **полный контракт экрана**. И самая важная часть screen spec — это перечисление состояний.

Industry-консенсус (Material Design, Atlassian Design, UXMatters, Trendyol Tech) на 2026 — UI-секция обязана покрывать **минимум четыре состояния каждого экрана**:

1. **Loading** — данные грузятся (>200ms). Skeleton с placeholder-блоками той же структуры, что и контент.
2. **Empty** — данных нет, но это норм. Иллюстрация + объяснение + primary CTA.
3. **Error** — запрос или действие сломалось. Иконка/текст + retry CTA.
4. **Content / Default** — собственно контент.

Плюс зачастую: **Partial** (часть данных есть, часть в ошибке), **Disabled**, **Offline**, **Success** (после действия).

В UX-комьюнити появилась мантра «**design empty states first**». Логика простая: если ты не знаешь, что показать когда данных нет, — ты не понимаешь экран. И я с этим согласен ровно после того, как увидел свой dashboard с AI-сгенерированным «Welcome to your journey» вместо нормального empty state.

Что должно быть в полной screen spec:

- Цель экрана и как туда попадают.
- Структура (см. ASCII wireframe — следующая глава).
- Поля и валидация (таблица: ID, тип, required, validation rule, inline error message).
- Все состояния (минимум четыре, чаще 5-7).
- Поведение элементов в виде EARS-правил.
- Mobile / Tablet / Desktop вариант.
- Accessibility-аннотации.
- Motion и transitions (с reduce-motion fallback).
- Design tokens, которые использовать.

Звучит как много. На практике это 70-100 строк markdown под одной User Story. Но эти 70 строк убирают примерно 90% уточняющих вопросов агента — то есть вы их пишете один раз вместо того, чтобы 5-7 раз гонять цикл «прокомментировал → исправил → опять не то».

---

## ASCII wireframes — главная антиинтуиция этого года

Это та часть, которая удивила меня сильнее всего, когда я начал копать.

Интуитивно кажется, что чем точнее я опишу визуал агенту, тем лучше будет результат. Дам Figma-экспорт с pixel-perfect разметкой, padding'ами, цветами в hex — агент же не дурак, он скопирует. Это логично, но **неправильно**.

Цитирую Peter Dedene, январь 2026, статья «ASCII wireframes: the antidote to over-specified AI builds»:

> «Дай агенту pixel-perfect Figma-экспорт с 12px padding и `#3B82F6` кнопкой — и агент потратит токены на воспроизведение твоих визуальных решений вместо решения структурных задач. Дай ASCII-wireframe — и агент сосредоточится на том, что важно: имеет ли смысл этот лейаут?»

И дальше:

> «В эпоху автономных кодинговых агентов это разделение [структурное vs эстетическое] — это разница между тем, что вы построили **то, что задумывали**, и тем, что вы дебажите **то, что AI импровизировал**».

Ассоциация, которая мне зашла: ASCII работает как **Balsamiq в 2010**. Помните, у них была эта рисованая «hand-drawn» эстетика? Это был forcing function. Когда стейкхолдер видел полированный мокап — он спорил про цвет кнопки. Когда видел кривые ящики — спорил про информационную архитектуру. То есть фиделити артефакта определяет фиделити обратной связи.

С агентами то же самое. Высокофиделити-вайерфрейм наполнен **скрытыми решениями**: «эти 16 пикселей gap между элементами — намеренные, или дизайнер просто отпустил элемент?» Человек инфериит интент. Агент — гадает.

ASCII убирает эту неоднозначность. Box это box. `[Button]` это кнопка. Агент не может over-interpret то, чего нет.

Технически это работает по двум причинам:

1. **Natural editability.** Когда я говорю агенту «сделай sidebar collapsible» — в ASCII это простая текстовая подстановка. В high-fidelity дизайне это reasoning про layout-engine, responsive-поведение, component state. Больше токенов, больше ошибок.
2. **Меньше implicit decisions.** Структуру проще обсуждать, когда визуал не отвлекает.

Готовый блок для копипасты в PRD (моноширинный шрифт, символы коробок ┌─┐│└┘):

```
Wireframe (desktop, ≥1024px):

┌────────────────────────────────────────────┐
│ [Logo]          [Search...]      [Avatar]  │  ← header (64px)
├────────┬───────────────────────────────────┤
│        │  Page Title                       │
│  Nav   │  ┌─────────────────────────────┐  │
│ [Home] │  │ Filters: [▾Type] [▾Date]    │  │
│ [Tasks]│  └─────────────────────────────┘  │
│ [Stats]│  ┌─────────────────────────────┐  │
│        │  │ Item 1                      │  │
│        │  │ Item 2                      │  │
│        │  │ Item 3                      │  │
│        │  │           [Load more]       │  │
│        │  └─────────────────────────────┘  │
└────────┴───────────────────────────────────┘

Wireframe (mobile, <640px):

┌────────────────────┐
│ [☰]  Logo  [Avatar]│
├────────────────────┤
│ Page Title         │
│ ┌────────────────┐ │
│ │[Search...]     │ │
│ └────────────────┘ │
│ [▾Filters]         │
│ ┌────────────────┐ │
│ │ Item 1         │ │
│ ├────────────────┤ │
│ │ Item 2         │ │
│ └────────────────┘ │
│   [Load more]      │
└────────────────────┘
```

Появилось два инструмента, которые помогают это рисовать без боли (раньше ASCII делать вручную в текстовом редакторе — это смерть глазам):

- **Mockdown.design** — бесплатный визуальный редактор от Mike Bespalov (250k+ юзеров на Refero). Drag-and-drop ящики, компоненты, экспорт в чистый Markdown, вставляешь в PRD — готово.
- **UXSCII.org** — open spec для UI-компонентов в текстовом виде. Двухфайловая система: `.uxm` (JSON-метаданные) + `.md` (ASCII-шаблон). Чисто для AI-агентов сделан.

Что ASCII **не покрывает** (важно, чтобы не было иллюзий):

- Цветовые соотношения и градиенты.
- Типографические иерархии.
- Motion и spatial-баланс.
- Сложные состояния (для них всё равно тексты + EARS).

ASCII — это про **структуру, иерархию, лейаут**. Эстетика отдельно (через design tokens). И это правильное разделение, потому что эти решения и должны быть отдельными.

---

## Component contracts — TypeScript как защита от plausible-but-wrong кода

Когда фронтенд строится на компонентах (React/Vue/Svelte/SwiftUI), агенту полезно дать **формальный контракт компонента**: какие props принимает, какие events эмитит, какие internal states. Это снимает огромный класс багов в стиле «агент понял компонент не так».

OpenAI публично подтверждает: structured outputs в strict-mode дают **почти 100% соответствия схеме** против <40% при «голом» промпте. Augment Code в 2026-шаблоне рекомендует input/output контракты через **Zod / JSON Schema / OpenAPI**, не через прозу. Логика та же: модели не умеют надёжно выводить типы из текста, но идеально работают с машиночитаемыми схемами.

Готовый блок для PRD:

```typescript
type RegistrationFormProps = {
  onSubmit: (data: { email: string; password: string }) => Promise<void>;
  onCancel?: () => void;
  initialEmail?: string;       // prefill из invite-link
  termsUrl: string;
  privacyUrl: string;
};

type SubmitError =
  | { code: 'EMAIL_EXISTS' }
  | { code: 'NETWORK' }
  | { code: 'SERVER'; message: string };
```

Плюс рядом текстом — **internal states**, события, slot-композиция, accessibility-контракт:

```
Internal states:
- idle (default)
- filling
- submitting
- error.network
- error.email_exists

Events:
- onSubmit вызывается при валидной форме. Возвращает Promise.
  Пока pending — submitting state. На reject — filling + error.

Accessibility contract:
- root: <form aria-label="Sign up">
- Submit button: aria-busy="true" в submitting
- Error banner: role="alert"
```

И ещё одна вещь, которая меняет всё, — **явное указание design system**. Это копируется почти дословно из дефолтного project-prompt Bolt.new и работает с любым агентом:

```
Design System Constraints:
- Use only components from shadcn/ui v0.9 (Button, Input, Form, Toast, Skeleton).
- Tailwind CSS variables only (e.g. bg-primary, text-muted-foreground).
- Icons: lucide-react только.
- Forms: react-hook-form + zod.
- Не устанавливать другие UI-библиотеки без явного запроса.
```

Без этого блока агент будет каждый раз ставить новые npm-пакеты на каждую кнопку. С ним — будет переиспользовать существующее.

---

## State tables — когда состояний становится больше пяти

Если у компонента >5 состояний или есть зависимости (форма-визард с 4 шагами, у каждого — подсостояния), линейные AC рассыпаются. Здесь приходит **state machine / state table** — формализм Дэвида Харела (statecharts), реализованный как XState.

Идея — явно перечислить все валидные состояния и переходы. Это позволяет агенту реализовать UI как finite-state machine и **отсечь невалидные комбинации** (типа «форма submitting и invalid одновременно» — это баг, который часто прорастает у агента, если состояния не перечислены).

Готовая таблица для PRD:

```
State machine: RegistrationForm

| From state    | Event              | Guard                  | To state          | Side effect                    |
|---------------|--------------------|-----------------------|-------------------|---------------------------------|
| idle          | INPUT_CHANGE       | —                      | filling           | —                              |
| filling       | INPUT_CHANGE       | form invalid          | filling           | —                              |
| filling       | INPUT_CHANGE       | form valid && tos OK  | filling.valid     | enable Submit button           |
| filling.valid | SUBMIT             | —                      | submitting        | call props.onSubmit            |
| submitting    | SUBMIT_SUCCESS     | —                      | (route to next)   | navigate('/onboarding')        |
| submitting    | SUBMIT_FAIL_409    | —                      | filling.email_err | show inline error under email  |
| submitting    | SUBMIT_FAIL_NET    | —                      | filling.net_err   | show top banner + retry button |
| filling.*     | RETRY              | —                      | submitting        | call props.onSubmit            |
```

Даже без библиотеки XState — таблица переходов сама по себе делает спеку **в разы детерминированнее**. Агент читает её один раз и потом просто реализует код 1:1.

Связка с EARS получается элегантная: state table показывает граф (структурно), EARS-правила описывают поведение в каждой ячейке (декларативно). Хороший паттерн — сначала state table, потом 2-3 EARS-правила на каждое нетривиальное состояние.

---

## Design tokens и DESIGN.md — вакцина от AI slop дефолтов

И последний кусок — про визуальный язык. Здесь интересный момент про современные модели.

В Anthropic Claude API Docs прямо написано про Claude Opus 4.7: «consistent default house style: warm cream/off-white backgrounds, serif display type (Georgia, Fraunces, Playfair), italic word-accents, terracotta/amber accent». Это не баг, это фича — модель действительно сильно подтянулась по фронтенду, но у неё есть **дефолтная эстетика**, которая хорошо работает для editorial/портфолио, и совсем не работает для dashboard/healthcare/enterprise.

Если вы делаете SaaS-dashboard и просто пишете «сделай красиво» — на выходе получите кремовый фон с serif-шрифтом и терракотовым акцентом. И будете долго дебажить, почему интерфейс выглядит как блог про вино, а не как панель аналитики.

Лечение — **явно перебить дефолты через design tokens** в начале PRD:

```
Design Tokens (must use, do not invent):

/* Colors */
--color-bg: #FAFAF7;
--color-bg-elevated: #FFFFFF;
--color-text-primary: #0E0E10;
--color-text-secondary: #4A4A52;
--color-accent: #C2410C;
--color-border-error: #DC2626;

/* Spacing (4px scale) */
--space-1: 4px; --space-2: 8px; --space-3: 12px;
--space-4: 16px; --space-6: 24px; --space-8: 32px;

/* Radii */
--radius-sm: 4px; --radius-md: 8px; --radius-lg: 12px;

/* Motion */
--duration-fast: 150ms;
--duration-normal: 250ms;
--easing-out: cubic-bezier(0.2, 0.8, 0.2, 1);

Tone / aesthetic direction: editorial, warm, generous whitespace.

Anti-patterns (запрещено):
- Не использовать дефолтные purple/indigo gradients.
- Не использовать system font без явного указания.
- Не делать «cookie-cutter SaaS» лейаут с одинаковыми колонками иконок.
```

И главное — **выносите это в отдельный файл `DESIGN.md` в корне проекта**, по аналогии с `CLAUDE.md` / `AGENTS.md` / `.cursorrules`. Этот файл агент читает как сплошной контекст при любой UI-задаче. Пишете один раз — работает на все будущие фичи. В апреле 2026 в Zenchaine на Zenn вышла подробная статья про эту практику, и я уже понял, что это правильный подход — иначе вы будете копировать одни и те же tokens в каждый PRD.

---

## Сравнительная таблица: какой фреймворк за что отвечает

Чтобы было видно картину целиком:

| Фреймворк | Точность | Снижение неоднозначности | Встраивание в PRD (US/AC) | Дружелюбность к агенту | Скорость написания | Что покрывает |
|---|---|---|---|---|---|---|
| **EARS** | высокая | сильное | идеально как нумерованные AC под US | высокая | средняя | поведение, edge cases |
| **Gherkin / GWT** | высокая | сильное | как .feature рядом или доп. секция | высокая, бонус: тесты | средняя | end-to-end сценарии |
| **Screen Spec** | очень высокая | максимальное | новая секция «UI Specification» под US | высокая | низкая (долго писать) | всё про экран |
| **ASCII wireframes** | средняя для лейаута / низкая для визуала | сильное для структуры | вставляется без инструментов | высокая, экономит токены | высокая | лейаут, иерархия |
| **Component Contract** | максимальная | сильное (Zod/TS) | секция к компоненту | высокая (~100% conformance) | средняя | API компонента, типы |
| **State Machine / Table** | максимальная | максимальное | таблица для тяжёлых компонентов | высокая (1:1 в код) | низкая для простых случаев | граф состояний |
| **Design Tokens / DESIGN.md** | высокая для визуала | убивает «AI slop» | один раз на проект | высокая | высокая (один раз) | визуальный язык |

Главный вывод из этой таблицы — **ни один из фреймворков не закрывает UI один**. Хороший PRD-блок про UI это **комбинация четырёх-пяти из них**, каждый отвечает за свой слой.

---

## Готовый шаблон UI-блока внутри User Story

Вот это — самое важное в статье. Это load-bearing момент. Дальше можно пропустить остальное, скопировать этот блок и адаптировать.

Принцип: вы **не ломаете каркас своего PRD**. Stream → Epic → User Story → AC остаются. Под Acceptance Criteria добавляется новая секция «🖼 UI Specification» с фиксированной анатомией. Всё.

Вот как это выглядит на примере регистрации:

```markdown
**[US-007][User] Как незарегистрированный пользователь, я хочу зарегистрироваться через email, чтобы получить доступ к продукту.**

**Acceptance Criteria (EARS):**
- [ ]  AC-1. WHEN the user opens /signup, the system shall display the registration form (SCR-001) in idle state.
- [ ]  AC-2. WHILE the form is being submitted, the system shall disable all inputs and show spinner inside Submit.
- [ ]  AC-3. IF the email is already registered (server returns 409), then the system shall show inline error «Account exists» under email field with link «Sign in instead».
- [ ]  AC-4. WHEN the form is submitted successfully, the system shall navigate to /onboarding within 500ms.
- [ ]  AC-5. IF the network is offline, then the system shall show top banner «You're offline» and queue submit for retry.

---

**🖼 UI Specification — SCR-001 Registration Form**

**Layout (desktop ≥1024px):**

\```
┌──────────────────────────────────────────────┐
│           [App Logo]                         │
│                                              │
│       Create your account                    │
│                                              │
│   ┌──────────────────────────────────────┐   │
│   │ Email                                │   │
│   │ [_______________________]            │   │
│   │                                      │   │
│   │ Password                             │   │
│   │ [_______________________]            │   │
│   │                                      │   │
│   │ ☐ I agree to ToS and Privacy Policy │   │
│   │                                      │   │
│   │  [    Create account    ]            │   │
│   │                                      │   │
│   │  Already have account? Sign in       │   │
│   └──────────────────────────────────────┘   │
└──────────────────────────────────────────────┘
\```

**Layout (mobile <640px):**

\```
┌────────────────────┐
│   [App Logo]       │
│ Create your account│
│ Email              │
│ [____________]     │
│ Password           │
│ [____________]     │
│ ☐ I agree to ToS  │
│ ━━━━━━━━━━━━━━━━━━ │
│ [Create account]   │ ← sticky bottom
│ ━━━━━━━━━━━━━━━━━━ │
└────────────────────┘
\```

**Состояния экрана:**

| State        | Visual                                              | Triggers entry                | Triggers exit                          |
|--------------|-----------------------------------------------------|-------------------------------|----------------------------------------|
| idle         | пустая форма, Submit disabled, без ошибок          | mount                         | INPUT_CHANGE                           |
| filling      | пользователь заполняет, Submit enabled при valid   | input event                   | SUBMIT                                 |
| submitting   | inputs disabled, Submit с spinner «Creating…»      | SUBMIT click                   | SUBMIT_SUCCESS / SUBMIT_FAIL_*         |
| error.email  | inline error под Email, link «Sign in»             | SUBMIT_FAIL_409                | INPUT_CHANGE на Email                  |
| error.net    | top banner + retry button                          | SUBMIT_FAIL_NETWORK            | RETRY click                            |
| success      | мгновенный redirect                                | SUBMIT_SUCCESS                 | (route change)                         |

**Поля и валидация:**

| Field       | Type     | Required | Validation                          | Inline error                                  |
|-------------|----------|----------|-------------------------------------|-----------------------------------------------|
| Email       | email    | yes      | RFC 5322                            | "Please enter a valid email"                  |
| Password    | password | yes      | ≥8 chars, ≥1 digit, ≥1 uppercase    | "8+ chars, 1 digit, 1 uppercase letter"       |
| ToS check   | checkbox | yes      | must be true                        | "Please accept the Terms to continue"         |

**Поведение (EARS, дополняет AC):**
- WHEN the user blurs Email, the system shall validate format and show inline error if invalid.
- WHILE the user is typing in Password, the system shall show a strength meter under the field (weak / fair / strong).
- WHEN all required fields are valid AND ToS is checked, the system shall enable the Submit button.
- IF the user tries to submit with disabled button (e.g. via Enter), then the system shall focus the first invalid field.

**Component contract:**

\```typescript
type RegistrationFormProps = {
  onSubmit: (data: { email: string; password: string }) => Promise<void>;
  termsUrl: string;
  privacyUrl: string;
  initialEmail?: string;
};

type SubmitError =
  | { code: 'EMAIL_EXISTS' }
  | { code: 'NETWORK' }
  | { code: 'SERVER'; message: string };
\```

**Accessibility:**
- `<form aria-label="Sign up">`.
- Каждый input имеет programmatic label.
- Inline-ошибки связаны с input через `aria-describedby`.
- Submit в submitting state — `aria-busy="true"`.
- Error banner — `role="alert"`.
- Контраст текста ошибки — минимум 4.5:1.
- Focus order: Email → Password → ToS → Submit → Sign in link.

**Motion:**
- Появление inline-error: fade-in 150ms ease-out.
- Spinner в Submit: 1s linear infinite rotation.
- При `prefers-reduced-motion` — все анимации мгновенные.

**Design tokens (см. DESIGN.md):**
- Background: `--color-bg`
- Card: `--color-bg-elevated`, `--radius-md`, `--shadow-md`
- Primary button: `--color-accent` background
- Error: `--color-border-error`, `--color-text-error`
- Spacing form-gap: `--space-4`

**UI out of scope:**
- Multi-language support (English только для v1).
- SSO/OAuth кнопки.
- CAPTCHA (отдельная фича).
- Анимация появления формы при mount.

**Notes:**
- Не показывать «email exists» до клика Submit (security: не утекать существование аккаунта на blur).
- В Submitting state не давать жать Submit повторно (idempotency).
- На мобильном не auto-focus Email при mount (мешает скроллу).
```

Получается **~80 строк под одной User Story**. Звучит много. На практике пишется за 15-20 минут. И эти 15-20 минут экономят 2-3 часа итераций с агентом, который без этих 80 строк будет три раза переделывать форму, пока не угадает, что вы имели в виду.

---

## Чек-лист: как обогатить вашу секцию AC под кодингового агента

Если вы дочитали до сюда и хотите практически встроить это в свой PRD-формат — вот пошагово.

**Шаг 1. Не меняйте каркас.**
User Story остаётся, AC в чекбоксах остаются, Stream/Epic иерархия остаётся. Меняется только то, что лежит **под AC** — добавляется UI-блок.

**Шаг 2. Перепишите AC в EARS-стиле.**
Каждое AC — одно из пяти EARS-шаблонов: Ubiquitous / Event / State / Unwanted / Optional. Это нулевые усилия, просто переформулировка существующих AC.

**Шаг 3. Под каждой User Story с UI добавьте блок «🖼 UI Specification».**
Внутри обязательно:

- [ ]  Layout — ASCII wireframe для desktop + mobile (5 минут работы).
- [ ]  Состояния экрана — таблица минимум 4 строки: idle, loading/submitting, empty (если применимо), error.
- [ ]  Поля и валидация — таблица: ID, тип, required, validation rule, inline error.
- [ ]  Component contract — TypeScript-типы props и события.
- [ ]  Accessibility — semantic HTML, ARIA, focus order.
- [ ]  Motion — duration/easing + reduced-motion fallback.
- [ ]  Design tokens — какие переменные использовать (или ссылка на DESIGN.md).
- [ ]  UI out of scope — что мы НЕ делаем в этой версии.

**Шаг 4. Один раз на проект — `DESIGN.md` в корне.**
Вынесите туда:

- Цветовые токены.
- Spacing scale.
- Type scale.
- Библиотеку компонентов (shadcn / Material / Fluent / ...).
- Tone-of-voice и anti-patterns.

И сошлитесь на этот файл в каждом PRD: «See `DESIGN.md` for design system constraints». Решает «AI slop»-проблему один раз и навсегда.

**Шаг 5. State table — там, где состояний больше пяти.**
Не для всего. Для регистрации с тремя полями таблица переходов избыточна. Для checkout flow с 4 шагами и 12 состояниями — обязательна.

**Шаг 6. Sanity check перед передачей агенту.**

- [ ]  Каждое состояние имеет визуальное описание (текст или ASCII).
- [ ]  Каждое поле имеет validation rule **и** error message.
- [ ]  Каждое interactive-действие имеет EARS-правило с триггером и реакцией.
- [ ]  Mobile-вариант описан или явно сказано «same as desktop, single column».
- [ ]  Перечислены design tokens для всех визуальных решений.
- [ ]  Accessibility — focus order, ARIA, контраст.
- [ ]  Motion — duration + reduced-motion.
- [ ]  «UI out of scope» — что мы НЕ делаем.

**Шаг 7. Тест регенерации.**
Augment Code в апрельском гайде предлагает классную проверку: через 1-2 недели после первой реализации — попросите агента **пересобрать UI заново из той же спеки**. Если результат сильно отличается — спека дырявая. Где именно — точка диагностики:

- Различаются названия error-полей → contract слабый.
- Появляется лишний функционал → раздел «Out of scope» неполный.
- Edge case в первой реализации, во второй — нет → AC table не покрывает явно.

Это обратная связь, по которой вы калибруете шаблон под свой codebase.

---

## А что мне с этого, если я просто PM в обычной компании?

Если вы дочитали и думаете «это всё для тех, кто пишет полностью на AI-агентах, а у меня живые разработчики», — я бы не стал так быстро это списывать.

Во-первых, грань стирается. Большая часть фронтенд-команд весной 2026 пишут **в режиме pair programming с агентом** — Cursor, Copilot, Claude Code. Даже если вы не отдаёте PRD прямо в Claude Code — ваш разработчик отдаёт. И качество того, что он получает на выходе из агента, прямо зависит от того, сколько контекста есть в спеке.

Во-вторых, есть уникальный side effect, который меня самого удивил. Когда я начал писать UI-блок по этому шаблону, я **сам стал лучше думать про UI**. Раньше я писал «пользователь видит ошибку» и спокойно шёл дальше. Теперь я обязан написать, **когда** именно он её видит, **как** она выглядит, **как** исчезает. И в половине случаев у меня нет ответа в момент написания. Я прихожу к дизайнеру и спрашиваю — и мы вместе понимаем, что в самой задумке фичи дырки.

То есть spec-driven approach — это **диагностический инструмент** на качество вашего собственного продуктового мышления. Если ваш PRD проходит этот формат с минимумом TBD — фича готова к реализации. Если у вас половина блоков «потом уточним» — значит, фича ещё сырая, и реализация всё равно будет идти в три захода.

В-третьих — и это самое главное — **PRD будет больше, но количество итераций уменьшится**. Это Pareto-оптимизация. Я лучше потрачу 30 минут на UI-блок, чем потом 3 часа гонять агента «не так, переделай». И это работает не только с агентами. С живыми разработчиками работает ровно так же. Ну может даже лучше — потому что ваш фронтендер давно хотел спросить, что показывать в empty state, но забывал на каждом стендапе.

---

## Главный takeaway

User Story в формате «Как [роль], я хочу [действие], чтобы [ценность]» работает. Acceptance Criteria в чекбоксах работают. Stream/Epic/JTBD/Backbone — всё это работает.

Что сломалось в эпоху кодинговых агентов — это **уровень детализации UI-секции**. Раньше под AC можно было писать 3-5 чекбоксов, и живой человек додумывал остальное. Теперь нужен полноценный UI-блок: ASCII wireframe + states table + validation table + EARS-правила + component contract + accessibility + motion + design tokens.

Звучит много. На практике это 70-100 строк под одной User Story и пишется за 15-20 минут. И режет 90% уточняющих вопросов агента.

Это не отдельный новый документ. Это **дополнительная секция под Acceptance Criteria**. Каркас вашего PRD не ломается. Просто там, где раньше было «пользователь видит форму» — теперь живёт детальный UI-блок, который агент может прочитать и сразу собрать интерфейс с первого раза.

Самая сильная цитата на эту тему, которую я нашёл — у Peter Dedene, январь 2026:

> «В эпоху автономных кодинговых агентов это разделение [структурное vs эстетическое] — это разница между тем, что вы построили **то, что задумывали**, и тем, что вы дебажите **то, что AI импровизировал**».

Между этими двумя реальностями — 80 строк markdown под каждой User Story. Это не так уж много за то, чтобы интерфейс получился с первого раза.

---

## Источники

Это всё лежит на полке индустрии, я ничего не выдумал. Если хотите глубже — основные ссылки:

**EARS и Spec-Driven Development:**
- Mavin A. (2009) «Easy Approach to Requirements Syntax (EARS)» — оригинальная статья.
- Alistair Mavin EARS — alistairmavin.com/ears
- GitHub Spec Kit — github.com/github/spec-kit
- Spec Kit Issue #1356 (EARS Integration) — github.com/github/spec-kit/issues/1356
- Microsoft Developer Blog (Sep 2025) — developer.microsoft.com/blog/spec-driven-development-spec-kit
- Martin Fowler «Understanding SDD: Kiro, Spec Kit, Tessl» (Oct 2025) — martinfowler.com/articles/exploring-gen-ai/sdd-3-tools.html

**Kiro (AWS):**
- Kiro Spec Guide — aicodingtools.blog/en/kiro/kiro-spec-guide
- DataCamp Kiro guide (Aug 2025) — datacamp.com/tutorial/kiro-ai
- Kiro requirements-template.md — github.com/jasonkneen/kiro/blob/main/spec-process-guide/templates/requirements-template.md

**Tessl и Augment Code:**
- Tessl framework launch (Sep 2025) — tessl.io/blog/tessl-launches-spec-driven-framework-and-registry
- Augment Code «AI Spec Template» (Apr 2026) — augmentcode.com/guides/ai-spec-template

**Gherkin / GWT:**
- Cucumber Gherkin Reference — cucumber.io/docs/gherkin/reference
- Martin Fowler «Given When Then» — martinfowler.com/bliki/GivenWhenThen.html

**Screen specs и состояния:**
- Material Design Empty States — m2.material.io/design/communication/empty-states.html
- Atlassian Design Empty State — atlassian.design/components/empty-state
- Trendyol Tech «Loading, Error, Empty and Content» — medium.com/trendyol-tech/simple-ui-problem

**ASCII wireframes:**
- Peter Dedene «ASCII wireframes: the antidote to over-specified AI builds» (Jan 2026) — medium.com/@dedene/ascii-wireframes-the-antidote-to-over-specified-ai-builds-6362862d8fc9
- Mockdown — mockdown.design
- UXSCII — uxscii.org

**State machines:**
- XState by Stately — xstate.js.org

**AI coding tools:**
- Anthropic Claude Code best practices — code.claude.com/docs/en/best-practices
- Anthropic Claude API prompting — platform.claude.com/docs/en/build-with-claude/prompt-engineering/claude-prompting-best-practices
- Anthropic frontend-design skill — github.com/anthropics/claude-code/blob/main/plugins/frontend-design
- Bolt prompting tips — bolt.new/blog/prompting-tips-for-bolt
- Vercel «How to prompt v0» — vercel.com/blog/how-to-prompt-v0
- David Haberlah «How to write PRDs for AI Coding Agents» (Jan 2026) — medium.com/@haberlah/how-to-write-prds-for-ai-coding-agents
- Zenchaine «Introduction to DESIGN.md» (Apr 2026) — zenn.dev/zenchaine/articles/design-md-ai-guidelines

---

*Stay tuned. И если у вас уже есть свой формат UI-блока — скиньте, мне любопытно сравнить.*
