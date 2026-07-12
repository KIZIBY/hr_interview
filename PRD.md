# PRD — микро-платформа технического интервью FDE, этап 2

Версия: 1.0 · Дата: 2026-07-07 · Статус: готов к реализации
Дизайн-контракт: `DESIGN.md` (корень репозитория) + `X5_Group_Design_System/`
Первоисточники контента: `Задачи на собеседование.docx`, `Техническое интевью этап №2, что спрашивать в целом.docx`, `Middle+ Forward Deployed Engineer.docx`

---

## 1. Обзор и цель

### Intent

Микро-платформа из двух статических HTML-страниц для проведения **второго (технического) этапа собеседования** на роль Forward Deployed Engineer (FDE) / Solution Builder — Middle+ в X5 Tech.

- `interviewer.html` — рабочая панель интервьюера: таймбоксинг 60 минут, банк задач, эталонные решения, сигналы «берём / стоп», оценочный лист с весами и GO/NO-GO-логикой. Кандидат эту страницу не видит.
- `candidate.html` — экран кандидата: текущая выбранная задача (условие, примеры, стартовый код) и редактор кода **без исполнения**. Никаких решений, сигналов и оценок.

Страницы синхронизируются между вкладками одного браузера на одной машине через BroadcastChannel (fallback — событие `storage` в localStorage): интервьюер выбирает задачу — у кандидата обновляется экран; код кандидата зеркалится в реальном времени обратно на панель интервьюера.

### Бизнес-контекст

Роль FDE — инженер, встроенный в бизнес: discovery, архитектура, реализация end-to-end, AI-native подход (Claude Code, Cursor, MCP как ежедневные инструменты). Главный риск этапа 2 — по формулировке гайда интервьюера — нанять «вайбкодера»: человека, который поднял агента через Claude Code, но не понимает, что у него под капотом. Поэтому этап проверяет инженерный фундамент под AI-инструментами: структуры данных, чтение и отладку кода, system design, проектирование агентов, прод-зрелость.

Сегодня интервьюер ведёт этап по текстовому гайду и .docx-файлам с задачами: приходится вручную пересылать условия кандидату, следить за временем по часам, держать решения и сигналы в отдельных окнах и заполнять оценочный лист постфактум. Платформа собирает всё это в один инструмент.

### JTBD

- **Интервьюер:** «Когда я веду 60-минутное техническое интервью, я хочу в одном окне видеть тайминг, банк задач с эталонами и сигналами, код кандидата и оценочный лист — чтобы держать структуру этапа и зафиксировать решение GO/NO-GO сразу после разговора, а не восстанавливать по памяти».
- **Кандидат:** «Когда мне дают задачу на интервью, я хочу видеть чистое условие с примерами и писать код в нормальном редакторе — чтобы сосредоточиться на рассуждении, а не на пересланных кусках текста в мессенджере».

### Метрика успеха v1

Интервью проходит от старта до вердикта без выхода из платформы: 0 переключений на .docx-файлы, оценочный лист заполнен в течение 10 минут после интервью (требование гайда — «зафиксируй оценку в течение 10 минут»).

---

## 2. Пользователи и сценарий

### Персоны

**Интервьюер** — инженер X5 Tech, ведёт этап 2 в одиночку. Технически грамотен, но во время интервью его внимание занято кандидатом: интерфейс должен требовать минимум действий (выбрать задачу — один клик, оценка — один клик на критерий). Устройство: ноутбук/десктоп, второй монитор или расшаренное окно для кандидата.

**Кандидат** — Middle+ инженер. Видит только свой экран: условие задачи и редактор. Волнуется; экран должен быть спокойным, без таймера, чужих элементов управления и намёков на оценку.

### Физическая схема сессии

Обе страницы открыты во вкладках **одного браузера на одной машине** интервьюера. Вкладка `candidate.html` выводится кандидату: второй монитор, развёрнутое окно на его половину экрана или демонстрация окна в видеозвонке с передачей управления. Реалтайм между разными машинами — вне скоупа v1 (нужен бэкенд).

### Основной флоу — 60 минут

1. Интервьюер запускает локальный сервер (`python -m http.server`), открывает `interviewer.html` и `candidate.html`, вторую вкладку выводит кандидату.
2. Панель показывает «кандидат подключён». Интервьюер нажимает «Старт» — пошёл таймер, подсвечивается сегмент 0–5.
3. **0–5** — разогрев, последний агентский проект кандидата. Задачи не выбраны, кандидат видит экран ожидания.
4. **5–18** — фундамент + разбор проекта. Интервьюер открывает карточки теории (PY-01, PY-02) на своей панели — это разговорные карточки, кандидату их пушить не обязательно.
5. **18–34** — агентские системы. Интервьюер пушит AGT-01: у кандидата появляется условие и свободный редактор-блокнот для набросков.
6. **34–48** — живой код или system design, по пробелу в сигнале. Интервьюер выбирает алгоритмическую задачу, отладку или SD-01 и пушит кандидату. Кандидат пишет код; интервьюер в реальном времени видит его на вкладке «Код кандидата» и параллельно смотрит эталон и сигналы.
7. **48–55** — добор по самой слабой зоне: ещё одна короткая задача или follow-up-вопросы из карточки.
8. **55–60** — вопросы кандидата. Интервьюер переключается на «Оценку».
9. Сразу после интервью интервьюер выставляет 1–4 по пяти критериям, система считает средневзвешенное и показывает вердикт GO/NO-GO. Результат переносится в ATS вручную (экспорт — TBD, раздел 11).

---

## 3. Скоуп и фазы

### v1 — FDE-набор под этап 2

- Две страницы: `interviewer.html`, `candidate.html`.
- Банк задач `tasks.json` — 19 позиций FDE-набора (раздел 5): алгоритмы, Python/SWE, отладка-антивайб, system design, агентский мини-дизайн, AI-augmented практика.
- Таймбоксинг 60 минут по сетке гайда: 0–5 / 5–18 / 18–34 / 34–48 / 48–55 / 55–60.
- Синхронизация вкладок: BroadcastChannel + fallback на `storage`-событие.
- Оценочный лист: 5 критериев с весами ×2/×2/×3/×3/×2, шкала 1–4, автоподсчёт, GO/NO-GO.
- Дизайн строго по X5 Group Design System.

### Фаза 2 — best practices топ-компаний

Deep-research по практикам технических собеседований в OpenAI, Meta, Google, Anthropic и других: структура этапов, калибровка сигналов, рубрики оценки, форматы задач. Затем — комбинирование FDE-набора с этими практиками: новые категории банка, уточнённые рубрики, возможно новые типы карточек. В v1 закладывается только расширяемость: банк — отдельный JSON, категории и критерии — данные, а не хардкод разметки. Детализация фазы 2 — вне этого PRD.

### Будущий расширяемый банк

Домены DL/NLP/CV/RecSys/Classic ML из исходного банка задач в v1 **не входят** (кроме двух опциональных ML-flavored отладочных сниппетов, см. раздел 5). Они остаются кандидатами на отдельные наборы для других вакансий.

### Non-goals

- Не система найма и не ATS: нет профилей кандидатов, истории интервью, аккаунтов.
- Не песочница исполнения кода: код не запускается, не проверяется автоматически.
- Не мультимашинный реалтайм: одна машина, один браузер.
- Не конструктор задач: банк редактируется руками в JSON.

---

## 4. Информационная архитектура

### Файлы

```
hr_interview/
├── interviewer.html          — панель интервьюера (standalone-страница)
├── candidate.html            — экран кандидата (standalone-страница)
├── guide.html                — гайд интервьюера и памятка решений (standalone-страница)
├── tasks.json                — банк задач v1 (единственный источник контента)
├── PRD.md · DESIGN.md
└── X5_Group_Design_System/   — токены, шрифты, логотипы (уже в репозитории)
```

Обе страницы импортируют `X5_Group_Design_System/colors_and_type.css` первым и грузят `tasks.json` через `fetch` — это ещё одна причина раздачи по http (fetch с `file://` блокируется, см. раздел 9).

### Что показывает каждая страница

| Зона | interviewer.html | candidate.html |
|---|---|---|
| Таймер и таймбокс-сетка | да — заголовочная зона | нет |
| Банк задач, фильтры | да — сайдбар | нет |
| Условие и примеры задачи | да — вкладка «Условие» | да — левая панель |
| Стартовый/багованный код | да | да — в редакторе |
| Эталонные решения | да — вкладка «Эталон и сигналы» | **никогда** |
| Сигналы 🟢/🔴, follow-ups, заметки оценки | да | **никогда** |
| Код кандидата | да — вкладка «Код кандидата», read-only зеркало | да — редактор |
| Оценочный лист, вердикт | да — вид «Оценка» | **никогда** |
| Статус подключения второй вкладки | да | нет |

Кандидат не видит: `referenceSolutions`, `buggyVersion`-пометки о том, что код багованный сверх текста условия, `followUps`, `greenSignals`, `redSignals`, `evaluationNotes`, оценки, таймер, банк задач. Страница `candidate.html` не содержит разметки и кода рендеринга этих полей вовсе — не «скрывает стилями», а не рендерит.

Ограничение честности: `tasks.json` технически доступен кандидату по URL, если он сядет за клавиатуру и откроет DevTools. Сессия очная и модерируемая, машина интервьюера — формальная защита контента вне скоупа v1 (раздел 9).

### guide.html — гайд интервьюера

Третья standalone-страница (спека `specs/001-interviewer-guide/spec.md`): рабочий документ интервьюера технического этапа 2 для инженера, который сам слабее кандидата. Закрывает подготовку (флоу 60 минут, пять зон проверки, речевые формулировки, правило GO/NO-GO) и экстренную подсказку во время интервью (памятка по каждой задаче банка).

- Разделы: «Как пользоваться», «Флоу этапа» (таймбокс сегментов, скрипт первых 5 минут, правила выбора задачи и слабой зоны, дежурный текст закрытия), «Пять зон проверки» (плюс антивайб-зонды и речевые мосты), «Сквозные сигналы», «Памятка по задачам», «Оценка и вердикт» (критерии, правило вердикта, памятка).
- Источник данных: карточки задач рендерятся в браузере через `fetch('tasks.json')` — тот же single source of truth, что и у пульта; новая задача появляется в памятке без правки гайда.
- Таблицы «Таймбокс сегментов» и «Критерии оценки» статически дублируют `SEGMENTS`/`CRITERIA` из `interviewer.js` (SYNC-CONTRACT, раздел 6 CLAUDE.md); гайд сверяет значения через `fetch` и пишет `console.warn` при дрейфе.
- Интеграция с пультом: ссылка «Гайд» в topbar `interviewer.html`; в деталях выбранной задачи — ссылка «памятка по задаче» → `guide.html#task-{id}` (контракт якорей карточек `id="task-{task.id}"`, строит `renderDetails()`).
- Конфиденциальность: гайд не для кандидата — первым элементом идёт предупреждающий баннер (держать в отдельном окне, свернуть перед шарингом), при печати сохраняется плашка «не передавать кандидатам». Доступность по URL кандидату — принятое ограничение статики (раздел 9), а не дефект гайда.

---

## 5. Модель данных — банк задач

### Схема задачи (contract)

`tasks.json` — объект `{ "version": 1, "tasks": Task[] }`. Схема одной задачи:

```typescript
type TaskCategory =
  | 'algorithms'      // Алгоритмы / CS-фундамент
  | 'python-swe'      // Python / SWE / Docker
  | 'debugging'       // Отладка кода — антивайб
  | 'system-design'   // System design
  | 'agents'          // Агентский мини-дизайн
  | 'ai-practice';    // AI-augmented практика

type TaskDifficulty = 'easy' | 'easy-medium' | 'medium' | 'advanced';

type TaskFormat =
  | 'code'            // условие + редактор с кодом
  | 'design'          // условие + свободный текстовый редактор-блокнот
  | 'discussion';     // карточка для разговора — редактор кандидату не показывается

type ScoringDimension = 'cs' | 'system-design' | 'agents' | 'production' | 'ai-practice';

type TaskExample = {
  input: string;            // как в банке: `strs = ["flower","flow","flight"]`
  output: string;
  explanation?: string;
};

type ReferenceSolution = {
  label: string;            // «Через zip», «XOR», «Эталонный Dockerfile»…
  code: string;
  complexity?: string;      // «O(n·m) время, O(1) память»
  notes?: string;           // на что смотреть в решении
};

type Task = {
  id: string;                    // стабильный ID вида CAT-##: 'ALG-01', 'DBG-02'
  category: TaskCategory;
  difficulty: TaskDifficulty;
  title: string;                 // sentence case, по правилам X5
  format: TaskFormat;
  prompt: string;                // условие; подмножество Markdown: абзацы, списки, `inline code`
  examples: TaskExample[];       // может быть пустым (теория, дизайн)
  starterCode: string | null;    // что кандидат получает в редакторе; null → редактора нет
  language: 'python' | 'dockerfile' | 'text' | null;
  referenceSolutions: ReferenceSolution[];   // interviewer-only
  buggyVersion?: string;         // для отладочных задач: если задан, в редактор кандидата
                                 // подставляется buggyVersion, а starterCode игнорируется
  followUps: string[];           // interviewer-only — вопросы для прокопки
  greenSignals: string[];        // interviewer-only — маркер 🟢 в UI
  redSignals: string[];          // interviewer-only — маркер 🔴 в UI
  evaluationNotes: string;       // interviewer-only — на что смотреть, типовые ловушки
  timeBudgetMin: number;         // рекомендованный бюджет в минутах
  scoringDimension: ScoringDimension;  // какой критерий листа кормит эта задача
  weight: 2 | 3;                 // вес критерия — денормализован для бейджа в списке
  links?: string[];              // внешние источники (LeetCode)
  mlSpecific?: boolean;          // опциональный ML-элемент — помечается бейджем
  status: 'ready' | 'todo-authoring';  // todo-authoring: условие/эталон не дописаны
};
```

Candidate-visible подмножество (единственные поля, которые `candidate.html` читает и рендерит): `id`, `title`, `format`, `prompt`, `examples`, `starterCode`, `buggyVersion` (как содержимое редактора, без пометки, что он багованный), `language`.

Контент полей `prompt`, `examples`, `starterCode`, `referenceSolutions`, `buggyVersion` берётся **дословно из банка задач** (`Задачи на собеседование.docx`) и гайда этапа 2 — не выдумывается. `greenSignals`/`redSignals` наполняются сквозными сигналами из гайда, специфичными для задачи follow-ups — из брифа гайда по соответствующей зоне.

### Инвентарь задач v1

| ID | Категория | Сложность | Название | Формат | Мин | Критерий | Статус |
|---|---|---|---|---|---|---|---|
| ALG-01 | algorithms | easy | Longest common prefix | code | 8 | cs | ready |
| ALG-02 | algorithms | easy | Group anagrams | code | 8 | cs | ready |
| ALG-03 | algorithms | easy | Single number — XOR или hashmap | code | 8 | cs | ready |
| ALG-04 | algorithms | easy | Valid parentheses | code | 8 | cs | ready |
| ALG-05 | algorithms | easy | String compression | code | 10 | cs | todo-authoring |
| ALG-06 | algorithms | easy-medium | Jump game | code | 10 | cs | ready |
| ALG-07 | algorithms | easy-medium | Maximize distance to closest person | code | 10 | cs | todo-authoring |
| ALG-08 | algorithms | easy-medium | Find K closest elements | code | 12 | cs | todo-authoring |
| ALG-09 | algorithms | easy-medium | Longest palindromic substring | code | 12 | cs | todo-authoring |
| ALG-10 | algorithms | easy-medium | Merge intervals | code | 10 | cs | todo-authoring |
| ALG-11 | algorithms | easy-medium | Summary ranges | code | 10 | cs | todo-authoring |
| PY-01 | python-swe | easy | Python — теория: mutable/immutable, ООП и SOLID, async против threading и multiprocessing, GIL | discussion | 8 | cs | ready |
| PY-02 | python-swe | easy | Docker — теория: контейнеризация против виртуализации, image против container, volumes | discussion | 6 | production | ready |
| PY-03 | python-swe | easy-medium | Ревью Dockerfile — найти проблемы | code | 8 | production | ready |
| DBG-01 | debugging | medium | Нейтральный Python/backend-сниппет с дефектом — off-by-one, гонка, мутация в цикле, N+1 | code | 12 | cs | todo-authoring |
| DBG-02 | debugging | medium | Багованный train-loop на torch — опционально, ML-специфична | code | 12 | cs | ready |
| DBG-03 | debugging | advanced | Багованный MultiHeadAttention — опционально, ML-специфична | code | 15 | cs | ready |
| SD-01 | system-design | medium | Офлайн-сканирование товаров — синк при появлении сети | design | 14 | system-design | ready |
| AGT-01 | agents | medium | Агент по регламентам с эскалацией человеку | design | 14 | agents | ready |
| AIP-01 | ai-practice | easy | AI-augmented практика — карточка-чеклист сигналов | discussion | 8 | ai-practice | ready |

Примечания к инвентарю:

- **ALG-05, ALG-07…ALG-11** — в банке есть только ссылки на LeetCode (`links`), полного локализованного условия и эталона нет. В v1 они входят в JSON со `status: 'todo-authoring'`: карточка рендерится, условие — заглушка со ссылкой. UI помечает их бейджем «требует авторинга» на панели интервьюера; кандидату их пушить можно, но не рекомендуется (подтверждающий диалог, US-02).
- **PY-01, PY-02** — вопросы из банка; на часть вопросов примерные ответы в банке пустые, поэтому `evaluationNotes` заполняется тем, что есть, остальное помечено в тексте заметки как «эталон не дописан».
- **PY-03** — багованный Dockerfile из банка (тег `python:latest`, порядок слоёв ломает кэш `pip install`) идёт в `buggyVersion`, эталонный фикс из банка — в `referenceSolutions`.
- **DBG-02, DBG-03** — ML-специфичные (`mlSpecific: true`), в FDE-интервью используются только как опциональные advanced-элементы для кандидатов с ML-бэкграундом. Багованные версии из банка — в `buggyVersion`, исправленные — в `referenceSolutions`. Основной антивайб-слот этапа — DBG-01, его авторинг — приоритетный TBD (раздел 11).
- **SD-01, AGT-01, AIP-01** — условия из гайда этапа 2 дословно; эталонного «решения» нет по природе задач — оценка через `followUps`, `greenSignals`, `redSignals`, `evaluationNotes`.

---

## 6. Контракт синхронизации

### Транспорт

- Канал: `new BroadcastChannel('x5-fde-interview-v1')`.
- Fallback: если `BroadcastChannel` недоступен — шина на localStorage: отправка `localStorage.setItem('x5-fde-interview-v1:bus', JSON.stringify(envelope))`, приём — обработчик события `window.addEventListener('storage', …)` с фильтром по ключу. Монотонный `seq` в конверте гарантирует изменение значения (иначе событие не сработает).
- Выбор транспорта — при загрузке страницы, одинаковой функцией на обеих страницах; смешивать транспорты в одной сессии нельзя.
- Персистентный снапшот: интервьюер при каждом изменении состояния пишет `localStorage['x5-fde-interview-v1:snapshot']` (сериализованный `SessionSnapshot`). Он нужен для восстановления после перезагрузки любой вкладки и как источник для поздно открытой `candidate.html`.

### Типы сообщений

```typescript
type Envelope<T extends string, P> = {
  v: 1;                                   // версия протокола
  type: T;
  payload: P;
  ts: number;                             // Date.now() отправителя
  seq: number;                            // монотонный счётчик отправителя
  source: 'interviewer' | 'candidate';
};

type Phase = 'setup' | 'running' | 'scoring' | 'done';

type TimerState = {
  status: 'idle' | 'running' | 'paused';
  accumulatedSec: number;                 // накоплено до последнего старта/паузы
  startedAt: number | null;               // Date.now() последнего запуска; null если не идёт
};                                        // elapsed = accumulatedSec + (now - startedAt)/1000

type SelectTaskMsg        = Envelope<'SELECT_TASK', { taskId: string }>;
type CandidateCodeMsg     = Envelope<'CANDIDATE_CODE_UPDATE', { taskId: string; code: string }>;
type TimerStateMsg        = Envelope<'TIMER_STATE', TimerState>;
type SessionStateMsg      = Envelope<'SESSION_STATE', {
  phase: Phase;
  currentTaskId: string | null;
  timer: TimerState;
}>;
type SyncRequestMsg       = Envelope<'SYNC_REQUEST', Record<string, never>>;
type ResetMsg             = Envelope<'RESET', Record<string, never>>;

type SyncMessage =
  | SelectTaskMsg | CandidateCodeMsg | TimerStateMsg
  | SessionStateMsg | SyncRequestMsg | ResetMsg;

type SessionSnapshot = {                  // localStorage ':snapshot', пишет интервьюер
  phase: Phase;
  currentTaskId: string | null;
  timer: TimerState;
  sentTaskIds: string[];                  // какие задачи уже пушились
  updatedAt: number;
};
```

### Правила протокола (EARS)

- WHEN either page loads, THE SYSTEM SHALL send `SYNC_REQUEST`.
- WHEN the interviewer page receives `SYNC_REQUEST`, THE SYSTEM SHALL respond with a full `SESSION_STATE` message.
- WHEN the candidate page receives `SYNC_REQUEST`, THE SYSTEM SHALL respond with `CANDIDATE_CODE_UPDATE` for the current task, if any code exists.
- WHEN the interviewer selects a task to push, THE SYSTEM SHALL broadcast `SELECT_TASK` with `taskId` only — the candidate page resolves the task from its own copy of `tasks.json` and renders only candidate-visible fields.
- WHILE the candidate is typing, THE SYSTEM SHALL debounce `CANDIDATE_CODE_UPDATE` to at most one message per 300 ms.
- IF a received message has `v !== 1`, THEN THE SYSTEM SHALL ignore the message silently.
- IF `CANDIDATE_CODE_UPDATE.payload.code` exceeds 50 000 characters, THEN the candidate page SHALL NOT send the update and SHALL show a length warning under the editor (limit protects the localStorage fallback).
- WHEN the interviewer page mutates phase, current task, or timer, THE SYSTEM SHALL broadcast `SESSION_STATE` and persist `SessionSnapshot`.
- WHEN `RESET` is broadcast, both pages SHALL return to their initial states and the interviewer page SHALL clear the snapshot and score draft.
- The candidate page SHALL treat `TIMER_STATE` messages as no-op in v1 (тип зарезервирован: восстановление таймера и будущий индикатор времени).

Замечание для реализации: BroadcastChannel не доставляет сообщение самой отправившей вкладке, а `storage`-событие не срабатывает в вкладке-отправителе — поведение симметрично, дополнительный код не нужен.

---

## 7. State machine сессии интервью

Состояния держит `interviewer.html`; `candidate.html` — проекция (`phase` + `currentTaskId`).

Состояния: `setup` → `running` (с подсостоянием «активная задача k») → `scoring` → `done`.

| From | Event | Guard | To | Side effect |
|---|---|---|---|---|
| (load) | INIT | нет снапшота | setup | отправить SYNC_REQUEST |
| (load) | INIT | есть снапшот | из снапшота | восстановить фазу, задачу, таймер, черновик оценок; broadcast SESSION_STATE |
| setup | START_SESSION | — | running | таймер: status=running, startedAt=now; broadcast SESSION_STATE + TIMER_STATE |
| setup | SELECT_TASK(k) | — | setup | задача пушится до старта таймера: currentTaskId=k; broadcast SELECT_TASK; пометить k в sentTaskIds |
| running | SELECT_TASK(k) | k ≠ currentTaskId; код кандидата пуст или подтверждён диалогом | running | currentTaskId=k; broadcast SELECT_TASK; пометить k |
| running | PAUSE_TIMER | timer.status = running | running | accumulatedSec += elapsed; status=paused; broadcast TIMER_STATE |
| running | RESUME_TIMER | timer.status = paused | running | startedAt=now; status=running; broadcast TIMER_STATE |
| running | OPEN_SCORING | — | scoring | таймер ставится на паузу; broadcast SESSION_STATE; главная область — вид «Оценка» |
| scoring | BACK_TO_SESSION | — | running | вернуть вид «Задача»; таймер остаётся на паузе (резюмировать вручную); broadcast SESSION_STATE |
| scoring | FINISH | все 5 критериев оценены | done | вычислить вердикт; заморозить входы листа; персист итога в localStorage; broadcast SESSION_STATE |
| done | REOPEN_SCORING | — | scoring | разморозить лист (правка после фиксации) |
| any | RESET | подтверждено диалогом | setup | очистить снапшот, черновики кода и оценок; broadcast RESET |

Инварианты (EARS):

- WHILE phase is `setup`, THE SYSTEM SHALL keep the timer at 00:00 and status `idle`.
- WHILE phase is `scoring` or `done`, the candidate page SHALL show the neutral final screen (US-05) instead of the last task.
- IF the interviewer page reloads mid-session, THEN THE SYSTEM SHALL restore phase, current task, timer, and score draft from the snapshot without losing more than the last 300 ms of candidate code.

---

## 8. User Stories — EARS + UI Specification

Общие соглашения для всех экранов: язык интерфейса — русский, sentence case, длинное тире; шрифт X5 Sans Regular/Medium; текст `--x5-ink`; логотип X5 — снизу слева каждой страницы; эмодзи в хроме интерфейса нет — маркеры 🟢/🔴 появляются только внутри данных сигналов задач. Все токены — из `X5_Group_Design_System/colors_and_type.css`, маппинг ролей — в `DESIGN.md`.

---

### US-01 [Interviewer] Обзор сессии и таймбоксинг

**Как интервьюер, я хочу видеть таймер и сетку таймбоксов этапа, чтобы держать структуру 60 минут, не глядя на часы.**

**Acceptance Criteria (EARS):**

- [ ] AC-1. WHEN interviewer.html loads and no snapshot exists, THE SYSTEM SHALL display phase `setup`, timer 00:00, and connection badge «кандидат не подключён».
- [ ] AC-2. WHEN any message with `source: 'candidate'` is received, THE SYSTEM SHALL switch the connection badge to «кандидат подключён» within 500 ms.
- [ ] AC-3. WHEN the user clicks «Старт», THE SYSTEM SHALL start the timer, set phase `running`, and broadcast `SESSION_STATE` and `TIMER_STATE`.
- [ ] AC-4. WHILE the timer is running, THE SYSTEM SHALL update the elapsed display every second and highlight the timebox segment matching elapsed time (0–5 / 5–18 / 18–34 / 34–48 / 48–55 / 55–60).
- [ ] AC-5. WHEN elapsed time crosses a segment boundary, THE SYSTEM SHALL move the highlight to the next segment within 1 second, without sound or popup.
- [ ] AC-6. IF elapsed time exceeds 60:00, THEN THE SYSTEM SHALL keep counting, render the overtime value in `--x5-danger` («60:00 +02:15»), and keep the last segment highlighted.
- [ ] AC-7. WHEN the user clicks «Пауза», THE SYSTEM SHALL pause the timer and broadcast `TIMER_STATE`; WHEN the user clicks «Продолжить», THE SYSTEM SHALL resume it.
- [ ] AC-8. WHEN the user clicks «Сброс», THE SYSTEM SHALL show a confirm dialog «Сбросить сессию — таймер, задачи и черновик оценки будут очищены»; IF confirmed, THEN THE SYSTEM SHALL reset to `setup` and broadcast `RESET`.
- [ ] AC-9. WHEN the interviewer page reloads mid-session, THE SYSTEM SHALL restore the timer from the snapshot, including time elapsed while the page was closed (расчёт от `startedAt`).

**🖼 UI Specification — SCR-I1 Заголовочная зона interviewer.html**

Layout (desktop ≥1024px) — фиксированная верхняя зона страницы, высота ~120px:

```
┌──────────────────────────────────────────────────────────────────────────────┐
│ Техническое интервью — FDE, этап 2      (кандидат подключён)   [Сброс]       │
│                                                                              │
│ 23:41 / 60:00   [Пауза]        фаза — интервью                               │
│ ┌0–5─┬5–18──────────┬18–34──────────────┬34–48───────────┬48–55───┬55–60──┐  │
│ │▓▓▓▓│▓▓▓▓▓▓▓▓▓▓▓▓▓▓│▓▓▓▓▓░░░░░░░░░░░░░░│░░░░░░░░░░░░░░░│░░░░░░░│░░░░░░│    │
│ │разо│фундамент     │агентские системы  │код или design │добор  │вопросы│   │
│ └────┴──────────────┴───────────────────┴───────────────┴───────┴───────┘   │
├──────────────────────────────────────────────────────────────────────────────┤
```

Layout (mobile <640px) — сетка сегментов сворачивается в одну строку-индикатор:

```
┌──────────────────────────┐
│ Интервью — FDE, этап 2   │
│ (кандидат подключён)     │
│ 23:41 / 60:00            │
│ [Пауза]  [Сброс]         │
│ сегмент — агентские      │
│ системы (18–34)          │
├──────────────────────────┤
```

Ширины сегментов сетки пропорциональны длительности: 5/13/16/14/7/5 минут → flex-grow 5/13/16/14/7/5.

**Состояния зоны:**

| State | Visual | Вход | Выход |
|---|---|---|---|
| setup | таймер 00:00 серый (`--x5-ink-quiet`), кнопка «Старт», сегменты пустые | mount без снапшота | START_SESSION |
| running | таймер `--x5-ink`, «Пауза», активный сегмент залит `--x5-citrus-soft`, пройденные — `--x5-surface-soft` | START_SESSION / RESUME | PAUSE / OPEN_SCORING |
| paused | значение таймера мигает раз в 2 s (opacity 1→0.5), кнопка «Продолжить» | PAUSE_TIMER | RESUME_TIMER / RESET |
| overtime | «60:00 +MM:SS», добавка в `--x5-danger`, последний сегмент активен | elapsed > 3600 s | RESET |
| disconnected | бейдж «кандидат не подключён» — светлый пилл с рамкой `--x5-divider` | mount | первое сообщение от кандидата |

Loading/empty/error-состояний у зоны нет — она не зависит от `tasks.json`.

**Поля и валидация:** ввода нет — только кнопки. Кнопки «Старт/Пауза/Продолжить» — одна кнопка с меняющейся меткой; «Сброс» — второстепенная, всегда доступна.

**Component contract:**

```typescript
type SessionHeaderProps = {
  phase: Phase;
  timer: TimerState;
  candidateConnected: boolean;
  onStart: () => void;
  onPause: () => void;
  onResume: () => void;
  onReset: () => void;          // вызывается после подтверждения диалогом
};

type TimeboxSegment = {
  fromMin: number; toMin: number; label: string;
};
// константа v1:
// [ {0,5,'разогрев'}, {5,18,'фундамент'}, {18,34,'агентские системы'},
//   {34,48,'код или design'}, {48,55,'добор'}, {55,60,'вопросы'} ]

// Internal states: тик setInterval 1000ms только в running;
// elapsed всегда пересчитывается от startedAt, не накапливается инкрементом.
```

**Accessibility:**

- Зона — `<header>`; таймер — `<time role="timer" aria-live="off">` (озвучивание каждую секунду недопустимо; смена сегмента анонсируется отдельным visually-hidden `aria-live="polite"` узлом: «сегмент — агентские системы»).
- Кнопки — настоящие `<button>`; focus ring 2px `--x5-ink` offset 2px.
- Сетка сегментов — `<ol>` с `aria-current="step"` на активном.
- Контраст: `--x5-ink` на белом ≈ 12:1; подписи сегментов ≥4.5:1 (использовать `--x5-ink-muted`, не `--x5-ink-quiet`, на заливках).
- Focus order: Старт/Пауза → Сброс → далее сайдбар банка задач.

**Motion:**

- Заливка сегмента при активации: background-color transition 320 ms `cubic-bezier(.2,0,0,1)`.
- Смена метки кнопки — без анимации.
- Мигание паузы: opacity 200 ms в обе стороны, период 2 s.
- `prefers-reduced-motion: reduce` — мигание паузы заменяется статичной меткой «пауза» рядом со временем; transition сегментов отключается.

**Design tokens:** фон зоны `--x5-surface`, нижняя граница `--x5-divider`; таймер `--fs-h3`/Medium; сегменты: радиус `--radius-xs`, подписи `--fs-caption`; активный `--x5-citrus-soft`, пройденный `--x5-surface-soft`, будущий — белый с hairline `--x5-divider`; overtime `--x5-danger`; бейдж подключения — паттерн `.x5-badge--light` / при подключении `--x5-success` текст.

**UI out of scope:** звуковые сигналы; браузерные нотификации; ручная перемотка таймера; редактирование сетки сегментов.

**Notes:** сетка — ориентир, не жёсткий скрипт (формулировка гайда), поэтому никаких блокировок по времени нет; таймер продолжает идти при переключении на вид «Оценка» до OPEN_SCORING.

---

### US-02 [Interviewer] Банк задач — выбор и push кандидату

**Как интервьюер, я хочу фильтровать банк задач по категории и сложности и отправлять выбранную задачу кандидату одним действием, чтобы не тратить время интервью на поиск.**

**Acceptance Criteria (EARS):**

- [ ] AC-1. WHEN interviewer.html loads, THE SYSTEM SHALL fetch `tasks.json` and render the task list grouped by category, in bank order.
- [ ] AC-2. WHILE `tasks.json` is loading (>200 ms), THE SYSTEM SHALL show a skeleton list of 6 placeholder rows.
- [ ] AC-3. IF the fetch fails, THEN THE SYSTEM SHALL show an error state with the exact reason hint «страница должна быть открыта по http — python -m http.server» and a retry button.
- [ ] AC-4. WHEN the user changes the category or difficulty filter, THE SYSTEM SHALL filter the list client-side within 100 ms; IF no tasks match, THEN THE SYSTEM SHALL show an empty state «нет задач под фильтр».
- [ ] AC-5. WHEN the user clicks a task row, THE SYSTEM SHALL open its details in the main area (US-03) WITHOUT pushing it to the candidate.
- [ ] AC-6. WHEN the user clicks «Показать кандидату», THE SYSTEM SHALL broadcast `SELECT_TASK`, mark the row with badge «у кандидата», and add the id to `sentTaskIds`.
- [ ] AC-7. IF the candidate's current code is non-empty and differs from the starter code, THEN THE SYSTEM SHALL show a confirm dialog «У кандидата есть код по текущей задаче — сменить задачу?» before pushing.
- [ ] AC-8. IF the chosen task has `status: 'todo-authoring'`, THEN THE SYSTEM SHALL show a confirm dialog «Условие задачи не дописано — показать кандидату?» before pushing.
- [ ] AC-9. WHERE a task is marked `mlSpecific`, THE SYSTEM SHALL render badge «ML» on its row and in details.

**🖼 UI Specification — SCR-I2 Сайдбар «Банк задач»**

Layout (desktop ≥1024px) — левая колонка 320px, скроллится независимо:

```
┌ Банк задач ──────────────────┐
│ [категория — все        ▾]   │
│ [сложность — все        ▾]   │
│                              │
│ Алгоритмы                    │
│ ┌──────────────────────────┐ │
│ │ ALG-01 Longest common    │ │
│ │ prefix    (easy) (8 мин) │ │
│ ├──────────────────────────┤ │
│ │ ALG-04 Valid parentheses │ │
│ │ (easy) (у кандидата)     │ │ ← выбранная сейчас
│ └──────────────────────────┘ │
│ Отладка — антивайб           │
│ ┌──────────────────────────┐ │
│ │ DBG-02 Train-loop torch  │ │
│ │ (medium) (ML)            │ │
│ └──────────────────────────┘ │
│ System design                │
│ │ SD-01 Офлайн-сканиро…    │ │
│ …                            │
└──────────────────────────────┘
```

Layout (mobile <640px): сайдбар становится выдвижной панелью во всю ширину, открывается кнопкой «Банк задач» под заголовочной зоной; в остальном идентичен desktop (single column).

**Состояния экрана:**

| State | Visual | Вход | Выход |
|---|---|---|---|
| loading | skeleton 6 строк (`--x5-surface-soft`, пульсация) | mount, fetch >200 ms | resolve/reject |
| content | сгруппированный список, фильтры активны | fetch ok | — |
| empty | «нет задач под фильтр» + кнопка «сбросить фильтры» | фильтр без совпадений | смена фильтра |
| error | текст ошибки + hint про http + [Повторить] | fetch reject | retry ok |
| row.selected | строка с заливкой `--x5-surface-alt`, hairline слева нет — заливка целиком | клик по строке | клик по другой |
| row.pushed | текстовый бейдж «у кандидата» (`--x5-success`) | SELECT_TASK | push другой задачи |
| row.sent | приглушённая пометка «показывалась» | задача была в sentTaskIds | RESET |

**Поля и валидация:**

| Field | Type | Required | Validation | Ошибка |
|---|---|---|---|---|
| Категория | select: все + 6 категорий | нет | — | — |
| Сложность | select: все / easy / easy-medium / medium / advanced | нет | — | — |

Фильтры комбинируются по AND; сбрасываются кнопкой в empty-state и при RESET.

**Component contract:**

```typescript
type TaskBankProps = {
  tasks: Task[];
  currentTaskId: string | null;
  sentTaskIds: string[];
  selectedTaskId: string | null;          // открыта в деталях (не обязательно у кандидата)
  onSelectTask: (taskId: string) => void; // открыть детали
  onPushTask: (taskId: string) => void;   // после всех confirm-диалогов
};

type TaskBankFilter = {
  category: TaskCategory | 'all';
  difficulty: TaskDifficulty | 'all';
};
// Internal states: filter (не персистится), collapsed-группы нет — список плоский внутри групп.
```

Строка задачи показывает: `id`, `title` (обрезка в 2 строки, ellipsis), бейджи `difficulty`, `timeBudgetMin` («8 мин»), опционально «ML», «требует авторинга», «у кандидата», «показывалась». Бейдж критерия и веса («агенты ×3») — в деталях, не в строке.

**Accessibility:**

- Список — `<nav aria-label="Банк задач">`, группы — `<section>` с заголовком `<h3>`, строки — `<button>` во всю ширину (не div с onclick).
- Выбранная строка — `aria-current="true"`.
- Фильтры — нативные `<select>` с `<label>`.
- Focus order: категория → сложность → строки списка по порядку.
- Skeleton — `aria-hidden="true"`, у списка `aria-busy="true"` при загрузке.

**Motion:** появление отфильтрованного списка — без анимации перестановок (мгновенно); hover строки — фон на 4% темнее за 120 ms `--ease-standard`; skeleton-пульсация — opacity 0.6↔1, 1.2 s, при `prefers-reduced-motion` — статичная заливка.

**Design tokens:** фон сайдбара `--x5-surface`; правая граница `--x5-divider`; строки — радиус `--radius-sm`, hover `--x5-surface-grey`, выбранная `--x5-surface-alt`; бейджи — паттерн `.x5-badge--light`, высота 22px, `--fs-caption`; «у кандидата» — текст `--x5-success`; «требует авторинга» — текст `--x5-warn`.

**UI out of scope:** поиск по тексту; drag-and-drop сортировка; избранное; счётчик «сколько раз давали задачу».

**Notes:** push и просмотр деталей — разные действия намеренно: интервьюер сначала сам смотрит условие и эталон, потом решает показывать; кнопка «Показать кандидату» живёт в деталях задачи (US-03), а не в строке списка — защита от случайного пуша.

---

### US-03 [Interviewer] Детали задачи — условие, эталон, сигналы, зеркало кода

**Как интервьюер, я хочу видеть условие, эталонные решения, сигналы и код кандидата в одном месте, чтобы вести разбор, не переключая окна.**

**Acceptance Criteria (EARS):**

- [ ] AC-1. WHEN a task is selected in the bank, THE SYSTEM SHALL render its details with tabs «Условие», «Эталон и сигналы», «Код кандидата».
- [ ] AC-2. WHEN no task is selected, THE SYSTEM SHALL show an empty state «выберите задачу в банке слева».
- [ ] AC-3. The «Эталон и сигналы» tab SHALL render `referenceSolutions` (метка, код, сложность, заметки), `followUps`, `greenSignals` с маркером 🟢, `redSignals` с маркером 🔴 and `evaluationNotes` — this content SHALL never be broadcast to the candidate page.
- [ ] AC-4. WHERE a task has `buggyVersion`, the «Эталон и сигналы» tab SHALL show the buggy code block labelled «что видит кандидат» above the reference fix.
- [ ] AC-5. WHEN `CANDIDATE_CODE_UPDATE` for the current task is received, THE SYSTEM SHALL update the mirror within 500 ms and show «обновлено HH:MM:SS».
- [ ] AC-6. WHILE the mirror updates, THE SYSTEM SHALL preserve the interviewer's scroll position in the mirror block.
- [ ] AC-7. IF the details tab is «Код кандидата» and the displayed task is not the pushed task, THEN THE SYSTEM SHALL show hint «кандидат сейчас видит другую задачу — ALG-04».
- [ ] AC-8. WHEN the user clicks «Показать кандидату» in the details header, THE SYSTEM SHALL trigger the push flow of US-02 (включая confirm-диалоги AC-7/AC-8 из US-02).
- [ ] AC-9. WHILE the pushed task differs from none (task is live), a live badge «у кандидата» SHALL be visible in the details header.

**🖼 UI Specification — SCR-I3 Главная область «Задача»**

Layout (desktop ≥1024px) — главная область справа от сайдбара; переключатель видов «Задача | Оценка» — сверху:

```
┌──────────────────────────────────────────────────────────────┐
│ [Задача]  [Оценка]                                           │
├──────────────────────────────────────────────────────────────┤
│ ALG-04 — Valid parentheses      (easy) (cs ×2) (8 мин)       │
│ (у кандидата)                    [Показать кандидату]        │
│ ─────────────────────────────────────────────────────────    │
│ [Условие] [Эталон и сигналы] [Код кандидата]                 │
│ ┌──────────────────────────────────────────────────────────┐ │
│ │ Рассмотрим последовательность из круглых, квадратных     │ │
│ │ и фигурных скобок…                                       │ │
│ │ ┌ пример ─────────────────────┐                          │ │
│ │ │ Input: s = "()[]{}"          │                         │ │
│ │ │ Output: true                 │                         │ │
│ │ └──────────────────────────────┘                         │ │
│ └──────────────────────────────────────────────────────────┘ │
│ …на вкладке «Эталон и сигналы»:                              │
│ ┌ решение — стек ──────────────┐ ┌ сигналы ───────────────┐  │
│ │ class Solution:              │ │ 🟢 сам объясняет O(n)   │  │
│ │     def isValid(self, s):    │ │ 🟢 читает чужой код     │  │
│ │         stack = []           │ │ 🔴 плывёт на структурах │  │
│ │ …        O(n) время          │ │ follow-ups: …           │  │
│ └──────────────────────────────┘ └────────────────────────┘  │
│ …на вкладке «Код кандидата»:                                 │
│ ┌ live · обновлено 14:32:05 ───────────────────────────────┐ │
│ │ def isValid(s):                                          │ │
│ │     stack = []                                           │ │
│ └──────────────────────────────────────────────────────────┘ │
└──────────────────────────────────────────────────────────────┘
```

Layout (mobile <640px): same as desktop, single column; шапка деталей сворачивается в две строки; вкладки скроллятся горизонтально.

**Состояния экрана:**

| State | Visual | Вход | Выход |
|---|---|---|---|
| empty | «выберите задачу в банке слева», без иллюстраций | mount / RESET | выбор задачи |
| content.condition | вкладка «Условие»: prompt + примеры моноширинными блоками | выбор задачи | смена вкладки |
| content.reference | эталоны, buggy-блок (если есть), сигналы, follow-ups, заметки | клик по вкладке | смена вкладки |
| content.mirror.live | код кандидата, метка «обновлено HH:MM:SS» | вкладка + задача = pushed | смена задачи |
| content.mirror.idle | подсказка «кандидат ещё не начал печатать» | pushed, кода нет | первый апдейт |
| content.mirror.other | hint «кандидат видит другую задачу — {id}» | детали ≠ pushed | push этой задачи |
| todo-authoring | плашка «условие не дописано — карточка со ссылками» над prompt | задача со status todo | — |

**Поля и валидация:** ввода нет; кнопка «Показать кандидату» disabled, когда задача уже у кандидата (бейдж вместо кнопки).

**Component contract:**

```typescript
type TaskDetailProps = {
  task: Task;                              // полная задача — страница интервьюера
  isPushed: boolean;                       // task.id === currentTaskId
  pushedTaskId: string | null;
  candidateCode: { code: string; updatedAt: number } | null;
  onPush: (taskId: string) => void;
};

type TaskDetailTab = 'condition' | 'reference' | 'mirror';
// Internal states: activeTab (сбрасывается на 'condition' при смене задачи);
// mirrorScrollLock: сохранять scrollTop блока зеркала между рендерами.
```

Рендер `prompt`: поддерживаемое подмножество Markdown — абзацы, маркированные списки, `inline code`, fenced-блоки кода. Никакого произвольного HTML из JSON (экранировать).

**Accessibility:**

- Вкладки — паттерн WAI-ARIA Tabs: `role="tablist"`, `role="tab"` + `aria-selected`, `role="tabpanel"`; стрелки влево/вправо переключают.
- Блоки кода — `<pre><code>` с `aria-label` («эталонное решение — стек», «код кандидата»).
- Зеркало — `aria-live="off"` (обновления каждые 300 ms нельзя озвучивать); метка времени — обычный текст.
- Маркеры 🟢/🔴 дублируются текстом: `<span aria-hidden="true">🟢</span> <span class="sr-only">сигнал берём:</span>` — смысл не только цветом/эмодзи.
- Focus order: переключатель видов → шапка деталей («Показать кандидату») → вкладки → контент.

**Motion:** смена вкладки — content fade-in 120 ms `--ease-standard` без сдвигов; обновление зеркала — без анимации (мигание недопустимо), метка времени обновляется тихо; при `prefers-reduced-motion` fade отключается.

**Design tokens:** шапка деталей — `--fs-h4` Medium; бейджи — `.x5-badge--light`; активная вкладка — underline 2px `--x5-ink`, неактивные — `--x5-ink-muted`; блоки кода — фон `--x5-surface-soft`, радиус `--radius-sm`, `--font-mono`, `--fs-body-sm`; колонка сигналов — карточка с hairline `--x5-divider`, радиус `--radius-card`; 🟢-строки — обычный текст, 🔴-строки — обычный текст (цветом не дублировать, маркер несёт семантику); плашка todo-authoring — фон `--x5-citrus-soft`? нет — предупреждение: текст `--x5-warn` на `--x5-surface-soft`.

**UI out of scope:** подсветка синтаксиса кода (v1 — моноширинный текст); diff кода кандидата с эталоном; аннотации/комментарии поверх кода; печать.

**Notes:** зеркало read-only принципиально — интервьюер не редактирует код кандидата; «Эталон и сигналы» — одна вкладка, а не две, чтобы во время ответа кандидата всё влезало в один взгляд; условие на вкладке «Условие» идентично тому, что видит кандидат (единый источник — `tasks.json`).

---

### US-04 [Interviewer] Оценочный лист с GO/NO-GO

**Как интервьюер, я хочу выставить оценки 1–4 по пяти взвешенным критериям и сразу получить вердикт GO/NO-GO, чтобы зафиксировать решение в течение 10 минут после интервью.**

**Acceptance Criteria (EARS):**

- [ ] AC-1. THE SYSTEM SHALL display exactly five criteria rows with weights: «CS-фундамент (структуры данных, сложность, чтение/отладка кода)» ×2; «System design (API, данные, конкурентность, масштабирование)» ×2; «Проектирование агентов (управляемость, состояние, сбои)» ×3; «Прод-зрелость (eval, observability, стоимость, guardrails)» ×3; «AI-augmented практика (понимает, что делает)» ×2.
- [ ] AC-2. WHEN the user selects a score 1–4 in any row, THE SYSTEM SHALL recompute the weighted average `Σ(score·weight)/12` immediately and render it with two decimals.
- [ ] AC-3. WHILE any of the five rows is unscored, THE SYSTEM SHALL show the average as «—» and the verdict as «заполните все критерии».
- [ ] AC-4. WHEN all five rows are scored, IF the weighted average ≥ 3.0 AND none of the rows «CS-фундамент», «Проектирование агентов», «Прод-зрелость» equals 1, THEN THE SYSTEM SHALL show verdict «GO»; ELSE THE SYSTEM SHALL show «NO-GO» with the failed rule spelled out («средневзвешенно 2.83 — ниже 3.0» / «оценка 1 в критерии — прод-зрелость»).
- [ ] AC-5. WHEN any score or comment changes, THE SYSTEM SHALL autosave the draft to localStorage within 1 second; WHEN the page reloads, THE SYSTEM SHALL restore the draft.
- [ ] AC-6. WHEN the user clicks «Зафиксировать», THE SYSTEM SHALL freeze all inputs, persist the final result, and move the session to `done`; a «Изменить» button SHALL allow reopening.
- [ ] AC-7. WHEN `RESET` is confirmed, THE SYSTEM SHALL clear scores, comments, and the frozen result.
- [ ] AC-8. The scale legend «1 — нет · 2 — слабо · 3 — норма для Middle+ · 4 — сильно» SHALL be permanently visible above the rows.

**🖼 UI Specification — SCR-I4 Вид «Оценка»**

Layout (desktop ≥1024px) — главная область, переключатель «Задача | Оценка»:

```
┌──────────────────────────────────────────────────────────────────┐
│ [Задача]  [Оценка]                                               │
├──────────────────────────────────────────────────────────────────┤
│ Оценочный лист — заполнить сразу после интервью                  │
│ 1 — нет · 2 — слабо · 3 — норма для Middle+ · 4 — сильно         │
│                                                                  │
│ ┌──────────────────────────────┬────┬─────────────┬────────────┐ │
│ │ Критерий                     │Вес │ Оценка      │ Комментарий│ │
│ ├──────────────────────────────┼────┼─────────────┼────────────┤ │
│ │ CS-фундамент (структуры      │ ×2 │ (1)(2)(3)(4)│ [________] │ │
│ │ данных, сложность, чтение…)  │    │      ▓3     │            │ │
│ │ System design (API, данные,  │ ×2 │ (1)(2)(3)(4)│ [________] │ │
│ │ конкурентность…)             │    │             │            │ │
│ │ Проектирование агентов …     │ ×3 │ (1)(2)(3)(4)│ [________] │ │
│ │ Прод-зрелость (eval, obs…)   │ ×3 │ (1)(2)(3)(4)│ [________] │ │
│ │ AI-augmented практика …      │ ×2 │ (1)(2)(3)(4)│ [________] │ │
│ └──────────────────────────────┴────┴─────────────┴────────────┘ │
│                                                                  │
│ Средневзвешенно — 3.17          Вердикт — GO                     │
│ правило — ≥3.0 без «1» в CS, агентах и проде                     │
│                                        [Зафиксировать]           │
└──────────────────────────────────────────────────────────────────┘
```

Layout (mobile <640px): таблица превращается в стопку карточек-критериев (название → сегмент-контрол 1–4 → комментарий); итоговая панель — sticky снизу:

```
┌────────────────────────┐
│ CS-фундамент  ×2       │
│ [1][2][▓3][4]          │
│ [комментарий________]  │
├────────────────────────┤
│ System design  ×2      │
│ [1][2][3][4]           │
│ …                      │
├━━━━━━━━━━━━━━━━━━━━━━━━┤
│ 3.17 — GO [Зафиксир.]  │ ← sticky bottom
└────────────────────────┘
```

**Состояния экрана:**

| State | Visual | Вход | Выход |
|---|---|---|---|
| draft.incomplete | часть строк без оценки; итог «—», вердикт «заполните все критерии» (`--x5-ink-muted`); «Зафиксировать» disabled | mount / RESET | все 5 оценены |
| draft.complete.go | итог числом, бейдж «GO» — заливка `--x5-success`, белый текст | правило GO выполнено | смена оценки |
| draft.complete.nogo | бейдж «NO-GO» — заливка `--x5-danger`, белый текст + строка с причиной | правило нарушено | смена оценки |
| frozen | все входы disabled (opacity .4), кнопка «Изменить» | «Зафиксировать» | «Изменить» |
| restored | как draft.*, тонкая строка «черновик восстановлен» на 5 s | reload с черновиком | таймаут |

**Поля и валидация:**

| Field | Type | Required | Validation | Ошибка/поведение |
|---|---|---|---|---|
| Оценка ×5 | radio group 1–4 (сегмент-контрол) | да — для вердикта | одно из 1/2/3/4 | без выбора строка учитывается как «не заполнено» |
| Комментарий ×5 | textarea 1–2 строки, autogrow до 4 | нет | ≤ 500 символов | счётчик после 400; ввод сверх лимита обрезается |

**Component contract:**

```typescript
type Criterion = {
  key: ScoringDimension;
  label: string;                 // точные формулировки гайда — AC-1
  weight: 2 | 3;
  critical: boolean;             // true для cs, agents, production — правило «без 1»
};

type ScoreSheetState = {
  scores: Partial<Record<ScoringDimension, 1 | 2 | 3 | 4>>;
  comments: Partial<Record<ScoringDimension, string>>;
  frozen: boolean;
  frozenAt: number | null;
};

type Verdict =
  | { kind: 'incomplete' }
  | { kind: 'go'; avg: number }
  | { kind: 'no-go'; avg: number;
      reason: 'avg-below-3' | 'one-in-critical';
      criterion?: ScoringDimension };

function computeVerdict(scores: ScoreSheetState['scores']): Verdict;
// avg = Σ(score·weight) / 12; округление отображения — 2 знака, сравнение с 3.0 — без округления.
```

**Accessibility:**

- Каждая строка — `<fieldset>` с `<legend>` = название критерия; оценки — radio-inputs с видимыми label 1–4.
- Вердикт — `role="status"` (озвучивается при смене), не `alert`.
- Frozen-состояние — `disabled` на inputs, не только стили.
- Контраст сегмент-контрола: выбранное значение — заливка `--x5-ink`, белая цифра (≥7:1).
- Focus order: строки сверху вниз, внутри строки 1→4 → комментарий; затем «Зафиксировать».

**Motion:** появление бейджа вердикта — fade+scale 0.98→1 за 200 ms `--ease-standard`; пересчёт числа — без анимации счётчика; `prefers-reduced-motion` — мгновенно.

**Design tokens:** таблица — hairline `--x5-divider-strong` между строками; сегмент-контрол — радиус `--radius-sm`, невыбранные — белый фон с рамкой `--x5-divider-strong`, выбранная — `--x5-ink`; бейджи GO/NO-GO — паттерн `.x5-badge` с заливками `--x5-success`/`--x5-danger`, радиус `--radius-pill`; строка причины — `--fs-body-sm` `--x5-ink-muted`; легенда шкалы — `--fs-caption`.

**UI out of scope:** экспорт (Markdown/PDF/ATS — TBD, раздел 11); история оценок прошлых сессий; сравнение кандидатов; подсказки-рубрики на каждый балл.

**Notes:** «Зафиксировать» не отправляет данные никуда — только замораживает и персистит локально; черновик автосейвится и без фиксации — защита от F5; оценка «1» в критических строках подсвечивает всю строку текстом причины сразу, не дожидаясь заполнения остальных (ранний сигнал NO-GO допустим визуально, но вердикт до полного заполнения — «заполните все критерии»).

---

### US-05 [Candidate] Экран задачи и редактор без запуска

**Как кандидат, я хочу видеть условие выбранной задачи и писать код в редакторе, чтобы показывать ход рассуждений, не отвлекаясь на лишний интерфейс.**

**Acceptance Criteria (EARS):**

- [ ] AC-1. WHEN candidate.html loads and no task has been pushed, THE SYSTEM SHALL show the waiting state «интервьюер выберет задание — оно появится здесь».
- [ ] AC-2. WHEN `SELECT_TASK` is received, THE SYSTEM SHALL render the task (title, prompt, examples) and fill the editor with `buggyVersion ?? starterCode` within 500 ms.
- [ ] AC-3. WHERE the task format is `discussion`, THE SYSTEM SHALL hide the editor entirely and render the prompt full-width.
- [ ] AC-4. WHERE the task format is `design`, THE SYSTEM SHALL show the editor as a plain-text notepad with placeholder «набросайте здесь API, схему данных или заметки».
- [ ] AC-5. WHILE the user is typing, THE SYSTEM SHALL send `CANDIDATE_CODE_UPDATE` debounced to one message per 300 ms.
- [ ] AC-6. WHEN the user presses Tab inside the editor, THE SYSTEM SHALL insert four spaces instead of moving focus; Escape followed by Tab SHALL move focus out (standard a11y escape hatch).
- [ ] AC-7. WHEN a different task is pushed, THE SYSTEM SHALL store the current draft per task id in sessionStorage; WHEN a previously shown task is pushed again, THE SYSTEM SHALL restore its draft instead of the starter code.
- [ ] AC-8. IF the editor content exceeds 50 000 characters, THEN THE SYSTEM SHALL stop broadcasting and show «код слишком длинный — синхронизация приостановлена» under the editor.
- [ ] AC-9. WHEN `SESSION_STATE` with phase `scoring` or `done` is received, THE SYSTEM SHALL replace the task with the neutral final screen «интервью завершено — спасибо».
- [ ] AC-10. WHEN `RESET` is received, THE SYSTEM SHALL clear the editor and drafts and return to the waiting state.
- [ ] AC-11. THE candidate page SHALL never fetch-render `referenceSolutions`, `followUps`, `greenSignals`, `redSignals`, or `evaluationNotes`, and SHALL contain no code paths that read these fields.
- [ ] AC-12. THE candidate page SHALL provide no run, submit, or execute affordance — the editor is typing-only; постоянная подпись «код здесь не запускается — важен ход рассуждений» видна под редактором.

**🖼 UI Specification — SCR-C1 candidate.html**

Layout (desktop ≥1024px) — две колонки 45/55, без хедера с навигацией:

```
┌────────────────────────────────────────────────────────────────────┐
│ Техническое интервью — X5 Tech                                     │
├──────────────────────────────┬─────────────────────────────────────┤
│ Valid parentheses            │  1  class Solution:                 │
│                              │  2      def isValid(self, s):       │
│ Рассмотрим последовательность│  3          stack = []              │
│ из круглых, квадратных       │  4          █                       │
│ и фигурных скобок…           │                                     │
│                              │                                     │
│ ┌ пример ──────────────────┐ │                                     │
│ │ Input: s = "()[]{}"      │ │                                     │
│ │ Output: true             │ │                                     │
│ └──────────────────────────┘ │                                     │
│ ┌ пример ──────────────────┐ │                                     │
│ │ Input: s = "(]"          │ │                                     │
│ │ Output: false            │ │                                     │
│ └──────────────────────────┘ │ ─────────────────────────────────── │
│                              │ python · код здесь не запускается — │
│                              │ важен ход рассуждений               │
├──────────────────────────────┴─────────────────────────────────────┤
│ [X5 logo]                                                          │
└────────────────────────────────────────────────────────────────────┘
```

Waiting state (та же страница до первого SELECT_TASK):

```
┌────────────────────────────────────────────┐
│ Техническое интервью — X5 Tech             │
│                                            │
│        Ожидание задачи                     │
│        Интервьюер выберет задание —        │
│        оно появится здесь                  │
│                                            │
│ [X5 logo]                                  │
└────────────────────────────────────────────┘
```

Layout (mobile <640px): single column — условие сверху, редактор ниже на 60vh; подпись «код не запускается» — под редактором; логотип — в подвале слева.

**Состояния экрана:**

| State | Visual | Вход | Выход |
|---|---|---|---|
| waiting | центрированный блок «Ожидание задачи», без спиннера | mount / RESET | SELECT_TASK |
| loading | скелет двух колонок ≤300 ms (только если tasks.json ещё грузится) | SELECT_TASK до fetch resolve | resolve |
| content.code | условие + редактор с кодом | SELECT_TASK, format code | смена задачи |
| content.design | условие + блокнот (plain text, placeholder) | format design | смена задачи |
| content.discussion | условие во всю ширину, редактора нет | format discussion | смена задачи |
| sync-paused | предупреждение лимита длины под редактором (`--x5-warn`) | >50 000 символов | удаление текста |
| finished | «Интервью завершено — спасибо», нейтральный экран | SESSION_STATE scoring/done | RESET |
| error | «не удалось загрузить задание — обновите страницу»; причина в консоль | fetch tasks.json reject | reload |

**Поля и валидация:**

| Field | Type | Required | Validation | Поведение |
|---|---|---|---|---|
| Редактор | textarea (моноширинный) | нет | мягкий лимит 50 000 символов | ввод не блокируется — останавливается только синк (AC-8) |

**Component contract:**

```typescript
type CodeEditorProps = {
  value: string;
  language: 'python' | 'dockerfile' | 'text';   // v1 — только подпись под редактором
  readOnly?: boolean;                            // false на candidate.html
  onChange: (value: string) => void;             // сырой ввод; debounce 300 ms — снаружи
  maxSyncLength: number;                         // 50 000
};

// Решение по редактору v1 — <textarea>, НЕ CodeMirror:
// 1. Исполнения нет — не нужны ни подсветка ошибок, ни автодополнение.
// 2. Ноль внешних зависимостей: страница работает в интранете без CDN,
//    что соответствует конвенции репозитория «standalone HTML».
// 3. Textarea — нативно доступен (скринридеры, IME, undo/ctrl+Z) без доп. работы.
// 4. Единственная надстройка — перехват Tab (4 пробела) с escape-hatch по Esc.
// CodeMirror 6 с CDN — задокументированная опция фазы 2 (подсветка синтаксиса),
// см. раздел 11; интерфейс CodeEditorProps выбран так, чтобы замена была drop-in.

type CandidatePageState = {
  phase: Phase;
  task: CandidateVisibleTask | null;   // подмножество Task — раздел 5
  draftsByTaskId: Record<string, string>;  // sessionStorage
  syncPaused: boolean;
};
```

**Accessibility:**

- Разметка: `<main>` из двух `<section aria-label="Условие">` / `<section aria-label="Редактор">`.
- Редактор — `<textarea aria-label="Редактор кода">` с `spellcheck="false"`, `autocapitalize="off"`, `autocorrect="off"`.
- Tab-перехват обязан иметь выход: после Escape следующий Tab уходит по фокус-циклу (AC-6).
- Смена задачи анонсируется `aria-live="polite"` узлом («новая задача — Valid parentheses»); фокус переводится на заголовок задачи `tabindex="-1"`.
- Waiting/finished-состояния — заголовок `<h1>`, читаемый скринридером.
- Контраст: код `--x5-ink` на `--x5-surface-alt` ≥ 10:1; подпись под редактором `--x5-ink-muted` ≥ 4.5:1.
- Focus order: заголовок задачи → текст условия → редактор.

**Motion:** появление новой задачи — fade-in контента 200 ms `--ease-standard` (обе колонки одновременно, без слайдов); waiting→content — то же; `prefers-reduced-motion` — мгновенно. Никаких анимаций во время набора текста.

**Design tokens:** фон страницы `--x5-surface`; заголовок задачи `--fs-h3` Medium; условие `--fs-body-lg` (крупнее обычного — читается с расстояния); блоки примеров — `--x5-surface-soft`, радиус `--radius-sm`, `--font-mono`; редактор — фон `--x5-surface-alt`, hairline `--x5-divider`, радиус `--radius-card`, `--font-mono` `--fs-body`; подпись — `--fs-caption` `--x5-ink-muted`; логотип — `assets/logos/x5-logo-color.svg`, снизу слева, отступ `--slide-margin`.

**UI out of scope:** подсветка синтаксиса; номера строк (v1 — без них: textarea, см. contract); кнопка «Готово»/отправка решения; таймер и любые элементы панели интервьюера; тёмная тема.

**Notes:** на экране кандидата нет ни одного намёка на оценку, тайминг и банк — снижаем стресс и не подсказываем структуру этапа; черновики per-task живут в sessionStorage (умирают с закрытием вкладки) — намеренно, см. TBD о хранении кода после сессии; language-подпись «python» — информационная, никакой валидации языка нет.

---

## 9. Нефункциональные требования

1. **Статика без бэкенда.** Два HTML-файла + JSON; никаких сборщиков, npm-зависимостей и серверного кода. Открываются из любой раздачи статики.
2. **Ограничение file:// (внести в инструкцию запуска).** BroadcastChannel и `storage`-события не работают между вкладками, открытыми как `file://` — каждая такая вкладка имеет opaque origin, и вкладки не считаются одним origin. `fetch('tasks.json')` c `file://` также блокируется. Синхронизация требует раздачи обеих страниц с одного origin по http(s): локально — `python -m http.server` из корня репозитория (страницы на `http://localhost:8000/...`), в проде — деплой статикой в общий набор онбординг-страниц. IF the pages are opened via `file://`, THEN each page SHALL detect it (`location.protocol === 'file:'`) and show a blocking notice with the launch command instead of silently failing.
3. **Браузеры.** Основной сценарий — десктопные Chromium/Firefox/Safari последних двух мажорных версий. Mobile — best-effort: страницы не ломаются и читаемы, но сценарий интервью — десктопный.
4. **Производительность.** Зеркало кода — debounce 300 ms, полезная нагрузка ≤ 50 000 символов; обновление зеркала не вызывает layout shift вне блока кода; `tasks.json` v1 ≤ 200 KB.
5. **Доступность.** Семантический HTML, ARIA-паттерны по разделу 8, контраст ≥ 4.5:1 для текста, полная клавиатурная навигация, `prefers-reduced-motion` учитывается на обеих страницах.
6. **Редактор без исполнения.** Никакого Pyodide, eval, воркеров: редактор — типографически аккуратный textarea (обоснование — component contract US-05). Отсутствие исполнения — продуктовое свойство: интервьюер оценивает рассуждение, а не зелёные тесты.
7. **Расширяемость контента.** Банк — отдельный `tasks.json`; добавление задачи или категории не требует правок HTML/JS (категории, критерии и сегменты таймбокса читаются как данные). Это же — точка встраивания результатов фазы 2.
8. **Персистентность.** Снапшот сессии, черновик оценки — localStorage; черновики кода кандидата — sessionStorage. Очистка — только через RESET.
9. **Конфиденциальность контента.** Эталоны и сигналы не покидают interviewer-страницу через канал синхронизации (передаётся только `taskId`). Физический доступ кандидата к `tasks.json` по URL считается вне модели угроз v1 — сессия очная и модерируемая; заметка для деплоя: не публиковать URL банка вне команды найма.
10. **Дизайн-система.** Обе страницы соблюдают `DESIGN.md` и жёсткие правила X5 (шрифт, ink, логотип, sentence case, без эмодзи в хроме).

---

## 10. Out of scope (v1)

- Реалтайм между разными машинами/браузерами (нужен бэкенд или WebRTC).
- Исполнение кода, автопроверка, тест-раннеры, подсветка ошибок.
- Аутентификация, роли, ссылки-приглашения.
- Серверное сохранение результатов, интеграция с ATS.
- Многоязычность UI (только русский; условия задач — как в банке).
- Домены DL/NLP/CV/RecSys/Classic ML как полноценные наборы (в v1 — только два опциональных ML-сниппета в категории отладки).
- Экспорт оценочного листа (решение по формату — TBD).
- Видеосвязь, чат, шаринг экрана — используется существующий инструмент звонка.

---

## 11. Открытые вопросы / TBD

| # | Вопрос | Контекст | Ответственный/срок |
|---|---|---|---|
| 1 | Экспорт заполненного оценочного листа — Markdown в буфер, PDF или копипаст-формат под ATS? | Сейчас результат переносится руками; формат зависит от процесса найма | нанимающая команда |
| 2 | Хранить ли код кандидата после сессии и где | v1: sessionStorage умирает с вкладкой; для разбора апелляций/калибровки может понадобиться выгрузка | нанимающая команда |
| 3 | Авторинг нейтрального антивайб-Python/backend-сниппета (DBG-01) | Главный слот этапа сейчас закрыт только ML-специфичными DBG-02/03; нужен сниппет 15–25 строк с off-by-one/гонкой/мутацией в цикле/N+1 | автор банка — до первого боевого интервью |
| 4 | Авторинг локализованных условий и эталонов для ALG-05, ALG-07…ALG-11 | В банке только ссылки на LeetCode | автор банка |
| 5 | Формат интеграции best-practices фазы 2 | Новые поля задач? Новые категории? Рубрики по баллам критериев? Решить после deep-research | фаза 2 |
| 6 | Подсветка синтаксиса (CodeMirror 6 с CDN) | Улучшение читабельности против зависимости от CDN в интранете | фаза 2 |
| 7 | Эталонные ответы на часть теории PY-01/PY-02 | В банке заголовки «Примерный ответ:» без текста | автор банка |

---

## 12. Тест регенерации

Проверка «дырявости» спеки по методичке (шаг 7): через 1–2 недели после первой реализации попросить агента собрать обе страницы заново **только из этого PRD + DESIGN.md + tasks.json**, не показывая первую реализацию. Сравнить:

- Различаются имена типов сообщений или поведение fallback — дырка в разделе 6 (контракт синхронизации).
- Во второй версии появился запуск кода, экспорт или таймер у кандидата — неполный раздел 10 (out of scope).
- Разошлись состояния экранов (пропал waiting/finished у кандидата, sync-paused и т.п.) — таблицы состояний в US-блоках не покрывают кейс явно.
- Разошлась формула или граничные случаи вердикта (округление, «1» в критических строках) — уточнить AC US-04.
- Вторая версия выглядит иначе (другие заливки, радиусы, появились градиенты) — дырка в DESIGN.md, а не в PRD.

Каждое расхождение фиксируется правкой соответствующего раздела, не устным договором.
