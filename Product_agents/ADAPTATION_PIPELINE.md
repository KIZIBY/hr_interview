# ADAPTATION_PIPELINE.md — пайплайн адаптации команды агентов к другим проектам

Status: ДЕЙСТВУЮЩИЙ (v1.14, 2026-07-04 — spec 010 OTel-экспорт (эпик 003 P7, замыкает эпик автономной платформы 7/7): `scripts/audit-to-otel.sh` в `CORE_SCRIPTS` — конвертер `audit.md` прогона → OTLP JSON в семантике OpenTelemetry GenAI (`invoke_agent`/`execute_tool`/usage-спаны); наблюдаемость харнеса в переносимом стандарте (любой OTel-инструмент или LV_DCP-приёмник читает trace без нашей инструментовки); спаривание :start/:done — ЕДИНЫЙ `pair_events`, вынесенный в `scripts/lib/deck-lib.pl` (ARCH-1 анти-дрейф с Flight Deck); детерминизм (id по индексу события + cksum пути, 0 дифф на повторе); on-prem guard устава I-1 (fail-closed allowlist loopback/private; cloud/публичный `--endpoint` → REJECT exit 3; auth приёмника только env `OTEL_EXPORTER_OTLP_HEADERS`); `--sink lvdcp` — advisory-мост в локальный LV_DCP portfolio (`lvdcp_audit_portfolio`), легитимно закрывает отложенный из P5 FR-8 код-мост audit→portfolio; новый §12 «LV_DCP-интеграция» сшивает RAG-дисциплину (P5) и trace-приёмник (P7); v1.13, 2026-07-04 — spec 009 unattended-цикл (эпик 003 P6, mothership-only): `/nightly` + `scripts/nightly-run.sh` — ночной backlog-drain волнами со стоп-кранами (9 SC: тройной бюджет-кран токены/время/волны, preflight, verify-commit zero-trust реального кода, assert-main-clean CWD-guard, combined-verify блокирует ОТЧЁТ, провал=ветка+тикет не main); публикация физически невозможна из скрипта (делегат `agent-publish-main.sh`); dev-волны за `NIGHTLY_ALLOW_DEV`; на базе 8 nightly-wave learnings (`docs/nightly-wave-orchestration-learnings-2026-07-04.md`); НЕ в поставке адаптаций (FR-15); v1.12, 2026-07-04 — spec 008 RAG-дисциплина: для индексированных LV_DCP-проектов (детект `.context/cache.db`) читающие код стадии (`pipeline-stage1` System Analyst mode=navigate, `pipeline-stage3` Tech Lead mode=edit) начинают с `lvdcp_pack` вместо слепого grep (фолбэк на Glob при недоступном MCP); `agent-env-audit.sh` печатает `[HINT] lvdcp_scan` для python-индексируемого-но-не-проиндексированного проекта (§1.5b); mothership сам not-indexed — дисциплина no-op; связка audit→portfolio (FR-8) — доктринальный указатель, код-мост → P7; v1.11, 2026-07-04 — spec 007 onboarding wizard: однокомандный путь `/onboard <target-root>` (mothership-only: `.claude/commands/onboard.md` + `scripts/agent-team-onboard.sh` — в поставку адаптаций НЕ входят, FR-11) — интервью ≤3 решений → `team.params` → конвейер `guards→bootstrap→env-audit→dod-check→smoke` с resume-журналом `docs/agent-onboarding/onboard-state.md` в цели → version-probe → LLM-калибровка stage-1 (чек-пойнт «зелёный stage-1 = онбординг завершён»); §8 получил маркеры `[auto:<имя>]`/`[manual]` — machine-readable пара к манифесту `DOD_AUTO_MANIFEST` скрипта, drift-guard множеств имён в `tests/run-tests.sh` (FR-7); v1.10, 2026-07-03 — spec 005 intake-канал: новая runtime-команда `/intake` (`.claude/commands/intake.md`) + скрипт `scripts/intake.sh` в `CORE_SCRIPTS` — хотелка владельца одной фразой → тикет (gh/tracker по `ISSUE_BACKEND`, авторство `[Owner]` по XTRACKER_FILING v1.1) → SPEC_DIR → stage-1; runtime-глоб adapt-скрипта отрефакторен в единую переменную `RUNTIME_GLOB` (тройной построчный дубль устранён); интейк-атрибуты тикета — mode-параметры `team.params` (§4); v1.9, 2026-07-03 — spec 002 G6/sync-status: `{{TRACKER_QUEUE}}` — плейсхолдер очереди трекера (§4/§7; литерал очереди в канонах де-локализован, FR-21..24), `--sync-status` в `agent-team-adapt.sh` — read-only отчёт отставания адаптации от mothership (FR-19/20); G2: preflight ведёт issue-часть по `ISSUE_BACKEND` — tracker → `xt ping` с timeout и redact, gh = зеркальный fallback, §10 «обещание» стал фактом (FR-1..4); G5: `Ticket:` в state.md + идемпотентный `link-ticket` + событие `ticket:linked` + spec-lint warn тикет-источника (FR-14..18); G3: секция ticket-flow в `dora-metrics.sh` — gh `--limit 500`, TTL-кэш 15 мин в `$TMPDIR`, `--tickets-file` для офлайн-тестов, полная graceful-деградация (FR-5..13); v1.8, 2026-07-02 — spec 001 самохостинг: устав mothership v1.0.0 занял `docs/constitution.md`, X5-референс → `docs/constitution.x5-reference.md` (git mv, ссылки обновлены); v1.7, 2026-07-02 — по аудиту 2026-07-02: классы «скрипты пайплайна» (синк в `--update-core` с `.bak`) и «runtime-команды» (DIVERGED-репорт в `--update-core`, перезапись — `--update-runtime` с `.bak`, баннер нормализуется), CFR приведён к канону Accelerate (fail/все попытки; инциденты — аннотацией), сравнения sync-канала идемпотентны; v1.6, 2026-07-02 — +шаблон устава `docs/constitution.template.md` и `OPERATIONS_GUIDE.md` (seed), +plan-lint/traceability, +слоистые правила `docs/pipeline-rules.md`, +worktree-per-unit stage-3, +intent-brief эпиков, +speckit-обвязка state/линтами; v1.5 2026-07-02 +NFR-доктрина (`NFR_GUIDE.md`, seed), +Units of Work/scope/learnings в `/pipeline`, +runtime-команды pipeline/speckit и `docs/constitution-check.md` в поставке (seed, с баннером локализации), +`agent-worktree-memory-check.sh`; v1.4 2026-07-02 +state-машина `/pipeline` (`pipeline-state.sh`+`spec-lint.sh`: resume, детерминированные гейты, append-only audit); v1.3 2026-07-02 +§11 SSO-режим (`SSO_AUTH_GUIDE.md`); v1.2 2026-06-30 +§0 стартовый гайд, +Шаг 1.5 онбординг/аудит окружения, +tracker-режим ISSUE_BACKEND; база v1.1 +zemlemer/xtracker; v1.0 2026-06-10). Owner: владелец; механика — `scripts/agent-team-adapt.sh` + `scripts/agent-env-audit.sh`.
Реестр живых адаптаций: `Product_agents/ADAPTATIONS.md`. HRI — **mothership** (материнский канон).
Устав mothership: `docs/constitution.md` v1.0.0 (16 слотов I-1…I-16, spec 001); reference-пример живого устава инстанса — `docs/constitution.x5-reference.md` (X5_BM v1.3.0).

---

## 0. Стартовый гайд — что делает этот пайплайн

**Если ты впервые видишь этот файл — прочитай сначала это.**

Пайплайн переносит **команду агентов** проекта HRI (mothership) в другой проект. Команда —
набор автономных агентов: **Kulibin** (пишет код, закрывает тикеты), QA-агенты
(**renata/semiglazka/her/zemlemer** — ищут баги через видимый браузер и меряют продукт),
**Pushkin** (документация), **Dobivatel** (гигиена git/памяти), **xtracker/Пристав** (тикеты во
внешнем трекере вместо GitHub-issues). Каждый агент = ПОРТИРУЕМОЕ ЯДРО (личность, правила,
методология) + ПРОЕКТНЫЙ СЛОЙ (URL/репо/стек/команды): пайплайн переносит ядро механически,
слой локализует осознанно (§1, §6).

**End-to-end за один проход:**

```
Шаг 0   Intake        — заполнить team.params, выбрать состав по матрице §3
Шаг 1   Bootstrap     — bash scripts/agent-team-adapt.sh <root> team.params   (каноны+стабы+память)
Шаг 1.5 Онбординг     — агенты анализируют репо (Onboarding Report) + scripts/agent-env-audit.sh (аудит плагинов/MCP/CLI)
Шаг 2   Локализация   — переписать доменный слой под проект (по картам §6 + Onboarding Report)
Шаг 3   BLOCKING-чек  — каждое «ОБЯЗАТЕЛЬНО» проверить на исполнимость
Шаг 4   Version-probe — подтвердить, что стаб → канон → правильный проект
Шаг 5   Порт кода     — (если в составе zanuda) перенести e2e-харнесс
Шаг 6   Обучение      — калибровочный прогон каждого агента на репо (потребляет Onboarding Report)
Шаг 7   Sync-контракт — периодическая сверка strict-core с mothership (--update-core)
```

**Однокомандный путь (onboarding wizard, spec 007 — mothership-only):** `/onboard <target-root>`
в сессии mothership — интервью-анкета (≤3 вопроса-решения) → `team.params` →
`bash scripts/agent-team-onboard.sh <target-root> <team.params>` (фазы
`guards→bootstrap→env-audit→dod-check→smoke`, resume после обрыва) → version-probe →
LLM-калибровка stage-1. Автоматизирует шаги 0–1.5 + DoD-срез §8 и калибровку; шаги 2/3/5/6
остаются ручными и приходят next steps в onboard-отчёте. В поставку адаптаций wizard НЕ входит.

**Минимальный жизнеспособный состав:** Kulibin + (renata ИЛИ semiglazka) + Pushkin.
**Где что лежит:** каноны — `Product_agents/Dev_Agents/`; runtime-стабы — `.claude/agents/` (тонкие,
анти-дрейф); правила памяти — `Product_agents/MEMORY_CONVENTION.md`; реестр живых адаптаций —
`Product_agents/ADAPTATIONS.md`.
**Трекер вместо GitHub-issues:** §10 «Tracker-режим» + `Product_agents/PRISTAV_TRACKER_GUIDE.md`.
**Корпоративный SSO (X5 Ключ и т.п.):** §11 «SSO-режим» + `Product_agents/SSO_AUTH_GUIDE.md`.
**LV_DCP-проект (Python с `.context/cache.db`):** §12 «LV_DCP-интеграция» — RAG-дисциплина чтения (spec 008)
+ trace-приёмник `audit-to-otel.sh` (spec 010) + `lvdcp_pack`/`lvdcp_scan`/`lvdcp_audit_portfolio`.

Дальше: принципы (§1), состав поставки (§2), матрица применимости (§3), анкета (§4), сам пайплайн
по шагам (§5), карты локализации (§6), карта замен (§7), DoD (§8), анти-паттерны (§9), tracker-режим (§10),
SSO-режим (§11), LV_DCP-интеграция (§12).

---

## 1. Принципы (выводы аудита 2026-06-10 — в фундамент, не в примечания)

1. **Ядро / слой.** Каждый агент = ПОРТИРУЕМОЕ ЯДРО (личность, iron rules, методология,
   форматы отчётов, memory-протокол) + ПРОЕКТНЫЙ СЛОЙ (URL, репо, стек, команды,
   тест-пользователи, доменная taxonomy, доменные ловушки). Пайплайн переносит ядро
   механически, слой — осознанной локализацией по картам (§6). Смешивать запрещено.
2. **Анти-дрейф by construction.** В целевом проекте с первого дня: runtime-копии =
   тонкие стабы → канон; entrypoint'ы расписаний = указатели; полные копии запрещены
   (инцидент F-2: runtime her/renata две недели жили без owner-секции BUG-HUNTER).
3. **Никаких невыполнимых BLOCKING-правил.** Каждое «ОБЯЗАТЕЛЬНО» в адаптации проверяется
   на исполнимость в целевой среде (инструмент доступен? путь существует? объём реален?).
   Невыполнимое BLOCKING учит игнорировать BLOCKING вообще (урок F-4).
4. **Hard-гейты ≠ coverage-цели.** Aspirational-нормы (10+ сущностей, 90% routes, 12 ролей)
   переносятся ТОЛЬКО как измеряемые цели с честным gap-отчётом; гейты — только evidence,
   честность, no-dup, no-simulation (урок F-8).
5. **Data sacred переносится как ценность №1**, даже если целевой проект «не юридический»:
   append-only память, archive-not-delete, никакие чистки без сохранения.
6. **Zero-trust един для всех адаптаций:** claim принимается только со свежим evidence
   на другой оси; «FIXED» агента — не доказательство.

## 2. Что входит в поставку «команда»

**Агенты (каноны в `Product_agents/Dev_Agents/`):** Kulibin (autonomous dev),
agent-renata (workflow-QA + verify-gate), semiglazka (ночной визуальный QA, 8+9 оптик),
zemlemer (продуктовый QA — стоимость маршрута по KLM-GOMS; новый, канон `zemlemer.md`, 2026-06-15),
agent-her (QA-оркестратор банды, вкл. группы-наследники secretary-lifecycle/admin-ops),
zanuda (e2e-харнесс + issue-sync), Pushkin (док-куратор + AGENTS.md guardianship),
Dobivatel (git/память/стабы-гигиена),
xtracker/Пристав (оператор ВНЕШНЕГО трекера тикетов — канон `Pristav.md`, новый 2026-06-24;
порт ТОЛЬКО если проект ведёт тикеты вне GitHub-issues, иначе встроенный `gh` Kulibin'а достаточно).

**Core-доки.** Четыре класса (два исходных разделены после боевого теста Ruscoffee 2026-06-10;
скрипты и runtime выделены после аудита 2026-07-02 — боевой дрейф X5_BM):
- **strict-core** (синкается `--update-core` с перезаписью+`.bak`): `BUG_HUNTER_RULES.md`,
  `MEMORY_CONVENTION.md`, `GIT_PUBLISH_RUNBOOK.md`, этот файл;
- **seed-доки** (копируются ТОЛЬКО при bootstrap, дальше — СЛОЙ адаптации, `--update-core`
  лишь сообщает о дивергенции): `docs/bug-handling-process.md`,
  `Product_agents/SSO_AUTH_GUIDE.md` (корпоративная аутентификация, §11),
  `Product_agents/NFR_GUIDE.md` (квантификация NFR), `Product_agents/OPERATIONS_GUIDE.md`
  (инциденты/runbook'и/откат), `docs/constitution-check.md` (gate-процедура — generic, DRY
  на устав проекта), `docs/constitution.template.md` (шаблон устава: универсальные инварианты +
  доменные слоты `[ЗАПОЛНИ]` — проект создаёт из него свой `docs/constitution.md` на Шаге 2);
- **скрипты пайплайна** (`CORE_SCRIPTS` в adapt-скрипте: preflight, pipeline-state, линты,
  dashboard, ops-log, dora-metrics, worktree-memory-check, intake) — код, не слой: байт-копия при
  bootstrap И синк `--update-core` с `.bak` (иначе багфиксы state-машины не доезжают до живых
  адаптаций); локальные правки скриптов запрещены — только upstream;
- **runtime-команды** `.claude/commands/pipeline*.md` + `speckit.*.md` + `intake.md` + `.claude/skills/pipeline.md`
  (единый список — переменная `RUNTIME_GLOB` в adapt-скрипте):
  рендер при bootstrap с баннером локализации (промпты стеко-зависимы, править на Шаге 2 под
  STACK); `--update-core` репортит NEW/up-to-date/DIVERGED (сравнение нормализовано — баннер
  не считается дивергенцией); перезапись DIVERGED — только `--update-runtime` (с `.bak`;
  слой промпта после синка переносится из `.bak` руками или уезжает upstream).
  Улучшения seed-слоя адаптация направляет upstream в mothership (как RusCoffee-форк 2026-06-06).

**Инфраструктура:** стаб-шаблон `.claude/agents/`, `scripts/agent-preflight.sh`
(вкл. root_hygiene), `scripts/pipeline-state.sh` + `scripts/spec-lint.sh` + `scripts/plan-lint.sh`
(state-машина, resume и детерминированные гейты 4-этапного `/pipeline`: state.md + append-only
audit.md per spec, units-referee, scope feature/enterprise, traceability FR/NFR→plan),
`scripts/pipeline-dashboard.sh` (Flight Deck: статический HTML-дашборд прогонов из
state.md/audit.md — DORA-панель + trace-таймлайн с длительностями, события `agent:*` через
`pipeline-state.sh event`), `scripts/ops-log.sh` + `scripts/dora-metrics.sh` (DORA и контракт
автономии ≥40% — `OPERATIONS_GUIDE.md` §5), `scripts/agent-worktree-memory-check.sh`
(детектор незакоммиченной памяти в worktree — гейт Dobivatel перед удалением), скелет
`AGENTS.md` (Canonical Locations + Team Status + routing + evidence rules), скелет памяти,
`docs/audit-evidence/` конвенция.

**Код zanuda-харнесса** (`e2e/tests/audit-sync/_helpers.ts`, `_run.sh`, `_extract.mjs`,
`_create-issues.mjs`, `intersections-parity.spec.ts`) — портируемый КОД с конфигом;
переносится на шаге 5, не скриптом.

## 3. Матрица применимости

| Агент | Нужно проекту | Фаза внедрения | Прим. |
|---|---|---|---|
| Kulibin | git-репо + issues + команды тестов/деплоя | **1 (ядро)** | стек-локализация TEST PROTOCOL |
| Pushkin | docs/ или wiki | **1 (ядро)** | + AGENTS.md guardianship с 1-го дня |
| renata | web-UI + ключевой пользовательский workflow | **1**, если есть UI | «секретарь» → доменный оператор |
| semiglazka | web-UI | **2** | детекторы (8.1–8.3, глаз 9) портируются почти как есть — самое переносимое ядро |
| zemlemer | web-UI + сквозной пользовательский флоу | **2** | методика KLM-GOMS — переносимое ядро, как у semiglazka; меряет стоимость маршрута, не пиксель/баг |
| Dobivatel | >1 пишущего агента/сессии | **2** | + monthly hygiene-sweep |
| xtracker/Пристав | тикеты во ВНЕШНЕМ трекере (не GitHub-issues) | **2 (условно)** | ядро = lifecycle-оператор; слой = API трекера + секрет. Нет внешнего трекера → не нужен (`gh` Kulibin'а достаточно) |
| zanuda | e2e-харнесс (или готовность его строить) | **3** | харнесс = отдельный порт кода |
| agent-her | зрелая команда + широкий продукт | **3–4** | стартовать с 4–6 групп, не 17 |

Минимальный жизнеспособный состав: **Kulibin + (renata ИЛИ semiglazka) + Pushkin**.
Прецедент TG_APP_COLLECT: kulibin + renata + semiglazka + zanuda (фазы 1–3 за месяц).

## 4. Анкета проекта (параметры адаптации)

Файл `team.params` (пример: `Product_agents/template/team.params.example`):

| KEY | Что это | Пример |
|---|---|---|
| PROJECT_NAME | Человекочитаемое имя | `TG_APP_COLLECT` |
| PROJECT_KEY | Короткий ключ (commit-scope, метки) | `TGAC` |
| PROJECT_ROOT | Абсолютный путь на машине-раннере | `/Users/x/projects/tgac` |
| GH_REPO | owner/repo | `lukinvit/TG_APP_COLLECT` |
| LIVE_URL | Прод/стейдж URL (для browser-QA) | `https://app.example.com` |
| STACK | Кратко: языки/фреймворки | `Python+FastAPI / React` |
| TEST_CMD_BACKEND | Команда тестов бэка | `pytest -q && ruff check && mypy` |
| TEST_CMD_FRONTEND | Команда тестов фронта (или `-`) | `npx tsc --noEmit && npm test` |
| DEPLOY_CMD | Команда деплоя (или `-`) | `bash scripts/deploy.sh` |
| TEST_USERS_DOC | Где лежат тест-пользователи | `docs/test-users.md` |
| EVIDENCE_ROOT | Корень evidence | `docs/audit-evidence` |
| AGENT_LANG | Язык команды | `ru` |
| MODEL | Модель frontmatter | `opus` |
| AGENTS | Состав (через запятую) | `kulibin,renata,semiglazka,pushkin` |
| ISSUE_BACKEND | Где живут тикеты: `github` или `tracker` (см. §10) | `github` |
| GIT_REMOTE | Где живёт код (push/PR); `-` = origin из GH_REPO | `-` (или `git@gitlab.internal:org/repo.git`) |
| TRACKER_TOOL | CLI трекера (если `ISSUE_BACKEND=tracker`) | `scripts/xtracker/xt.py` |
| TRACKER_QUEUE | Очередь/проект трекера (плейсхолдер `{{TRACKER_QUEUE}}`) | `BOARD` |
| TRACKER_TOKEN_PATH | Путь к токену трекера (вне репо, chmod 600) | `~/.<proj>_xtracker_token` |
| TRACKER_HOST | Хост трекера (плейсхолдер `{{TRACKER_HOST}}`) | `tracker.example.com` |
| SSH_TARGET | `user@host` доступа к среде (`{{SSH_TARGET}}`; `{{SSH_HOST}}`=после `@`) | `deploy@host.example.com` |
| CONTAINER_PREFIX | Префикс docker-контейнеров (`{{CONTAINER_PREFIX}}-…`) | `myproj` |
| TEST_EMAIL_DOMAIN(_ALT) | Домен(ы) тест-пользователей (`{{TEST_EMAIL_DOMAIN}}`) | `test.example.com` |
| TEST_PASSWORD | Пароль тест-юзеров (лучше env/secret, `{{TEST_PASSWORD}}`) | `-` |
| GIT_TOKEN_PATH | Путь к git-токену вне репо (`{{GIT_TOKEN_PATH}}`) | `~/.<proj>_git_token` |
| HOME_DIR | Домашний каталог раннера (`/Users/nikolaykoreshkov`) | `/Users/you` |
| SSO_PROVIDER | Корпоративный SSO продукта (`{{SSO_PROVIDER}}`, §11); для X5 — `X5 Ключ`; `-` = нет SSO | `X5 Ключ` |
| SSO_ISSUER_URL | Issuer OIDC-провайдера (`{{SSO_ISSUER_URL}}`) | `https://auth.x5.ru` |
| SSO_ADMIN_GROUP | Группа каталога (AD) → admin-роль (`{{SSO_ADMIN_GROUP}}`) | `X5_Portal_Admins` |
| INTAKE_TICKET_TYPE / INTAKE_TICKET_PRIORITY | Атрибуты owner-тикета канала `/intake` в tracker-бэкенде — **mode-параметры** (читает `scripts/intake.sh` в runtime; НЕ плейсхолдеры Model B, цепочка §7 не требуется); не заданы → дефолты | `task` / `normal` |

> Параметры де-локализации (Model B, §7): пустой/`-` → плейсхолдер остаётся в адаптированных файлах для осознанной локализации (Шаг 2).

## 5. Пайплайн — 8 шагов (вкл. Шаг 1.5 онбординг)

> Однокомандный путь шагов 0–1.5 (+DoD-срез §8 и калибровка): `/onboard <target-root>` —
> onboarding wizard (spec 007, mothership-only, см. §0). Ручные шаги 2/3/5/6 wizard печатает
> next steps'ами — сами шаги ниже остаются каноном.

**Шаг 0 — Intake.** Заполнить анкету §4. Решить состав по матрице §3. Зафиксировать
`UPSTREAM_SHA` (текущий main mothership).

**Шаг 1 — Bootstrap (механика).**
```bash
bash scripts/agent-team-adapt.sh <target-root> <team.params> [--agents a,b,c]
```
Скрипт (идемпотентен, существующие файлы НЕ перезаписывает — data sacred):
копирует core-доки и выбранные каноны с подстановкой параметров (карта замен §7),
ставит баннер «ADAPTED FROM upstream@SHA + TODO-карта локализации» в каждый канон,
генерирует тонкие стабы в `.claude/agents/` (frontmatter из канона), сидит память
с конвенцией, скелет `AGENTS.md`, копирует preflight, пишет `Product_agents/ADAPTATION.md`
(провенанс: upstream SHA, дата, состав, параметры).

**Шаг 1.5 — Онбординг (анализ репо + аудит окружения).** Адаптация команды к ПРОЕКТУ:
понять кодовую базу и проверить, что окружение готово. Две части, обе кормят Шаг 2.

- **1.5a Анализ репозитория (агенты, read-only).** Спавн read-only агентов (`Explore` +
  `system-analyst` + `Pushkin`) → **Onboarding Report** в `docs/agent-onboarding/<YYYY-MM-DD>-onboarding.md`:
  карта репо (директории/сервисы/слои), стек и команды сборки/тестов/деплоя, конвенции кода,
  существующие агенты/скиллы/инструменты, кандидаты в доменную taxonomy и доменные ловушки,
  frozen-контракты, **текущий механизм аутентификации** (SSO-провайдер / локальный логин, где живёт
  auth-код, откуда роли, как входят тест-юзеры — кормит §11 и `SSO_AUTH_GUIDE.md` §2).
  Это вход для локализации (Шаг 2) и обучения (Шаг 6) — не угадывай слой, выведи его.
- **1.5b Аудит окружения (скрипт, детерминированно).**
  ```bash
  bash scripts/agent-env-audit.sh <target-root> <team.params>
  ```
  По выбранному составу `AGENTS` + `ISSUE_BACKEND` вычисляет нужный/рекомендованный набор
  (browser-QA агент → playwright-MCP REQUIRED; kulibin → speckit + superpowers RECOMMENDED;
  `gh` REQUIRED при github-backend / токен трекера при tracker-backend; node/python по `TEST_CMD_*`),
  детектит установленное (`claude mcp list`, `.claude/skills`, `~/.claude/plugins/cache`, `command -v`)
  и печатает **gap + команды установки**. Advisory (exit 0, read-only, идемпотентен) — это
  coverage-цель с честным отчётом, НЕ гейт (принцип №4). Запускается и автоматически в конце Шага 1.
  **RAG-дисциплина (spec 008):** если lvdcp-MCP есть, а проект Python-индексируем, но `.context/cache.db`
  ещё нет — печатает `[HINT] lvdcp_scan(path=…)`; построй индекс, чтобы стадии пайплайна (System Analyst,
  Tech Lead) шли через `lvdcp_pack` вместо слепого grep (детект — наличие `.context/cache.db`; см. `CLAUDE.md`).

**Шаг 2 — Доменная локализация (осознанная, по картам §6 + Onboarding Report Шага 1.5a).**
Переписать coverage taxonomy, доменные ловушки, маршрутизацию, stop-list метки. Удалить X5-специфику.
Правило: НЕ изобретать новые iron rules — только локализовать слой. **При `ISSUE_BACKEND=tracker`** —
применить карту `gh`→`xt` из §10 (issue-операции → Пристав; push/PR остаются на git).

**Шаг 3 — Исполнимость BLOCKING-правил.** Пройти по каждому «ОБЯЗАТЕЛЬНО/BLOCKING»
адаптированных канонов: инструмент есть? путь есть? объём реален за прогон?
Невыполнимое → условная форма («при доступности») или вычеркнуть.

**Шаг 4 — Version-probe каждого агента.** Спавн с промптом-пробой (НЕ рабочий прогон):
«процитируй пункт 2 стаба; есть ли в промпте „runtime-стаб"; sed первые строки канона».
Подтверждает: стаб → канон → правильный проект. (Рецепт проверен в HRI 2026-06-10.)

**Шаг 5 — Порт кода (если zanuda/харнесс в составе).** Перенести `_helpers/_run/_extract/
_create-issues` + `intersections-parity.spec.ts`, заменить API_BASE/роли/сущности;
прогнать parity-спек — он же smoke нового харнесса.

**Шаг 6 — Обучение команды (первый боевой прогон + калибровка).** Это и есть «обучение»:
каждый агент читает **Onboarding Report** (Шаг 1.5a) + свой канон + локализованный слой и
делает один боевой прогон на репо с ЧЕСТНЫМ gap-отчётом (цель × достигнуто × gap, без симуляции).
По итогам — первая запись в память каждого агента и правки слоя. Обучать до локализации нельзя
(агент калибруется уже под проект) — поэтому обучение здесь, а не на Шаге 1.5.
DoD-чеклист §8 зелёный → запись в `ADAPTATIONS.md` реестр + строка проекта в локальный
`fleet.manifest` mothership (spec 004: флот-дашборд видит новую адаптацию сразу).

**Шаг 7 — Sync-контракт.** Назначить периодичность сверки с mothership (рекомендация:
при каждом уроке класса «все проекты» + ежеквартально): `agent-team-adapt.sh --update-core`
обновляет strict-core И скрипты пайплайна (с diff и `.bak`); по seed-докам и runtime-командам
выводится отчёт о дивергенции (слой не трогается), улучшения двигаются upstream. Синк
runtime-команд с перезаписью — отдельный явный `--update-runtime` (с `.bak`): гоняется после
каждого минорного релиза mothership (vX.Y), т.к. промпты /pipeline меняются чаще доктрин.

## 6. Локализационные карты (что в каноне ядро, а что слой)

**Kulibin:** ЯДРО — личность, Iron Rules 1–13, BUG-HUNTER при верификации фикса,
stop-list-механика, self-audit, сводка прогона, эскалации. СЛОЙ — Среда (URL/repo/пути),
TEST PROTOCOL (стек!), список «что НЕ делает» (frozen contracts проекта), метки stop-list.

**renata:** ЯДРО — философия/характер, Iron Rules 1–19 (вкл. display≠state, data-testid,
честный coverage), Angry User Team-механика, Fix/Around-Bug duty, формат находки/отчёта.
СЛОЙ — owner-директивы (объёмы пересогласовать с владельцем проекта!), Test Scope-разделы,
Known Architectural Traps, UC-сюиты (писать свои в `docs/qa/`).

**semiglazka:** ЯДРО — 8 оптик + детекторы 8.1/8.2/8.2-bis/8.3 + глаз 9, режимы
полный/раздел, hard-гейты/coverage-метрики, DOM-proof, memory-протокол, issue-формат.
СЛОЙ — routes-источники (пути к router'у проекта), роли, brand-baseline, фикс-рецепты
под дизайн-систему проекта.

**agent-her:** ЯДРО — личность, hard-гейты, coverage-цели-механика, dispatch-реальность
(браузерные последовательно + receipt-check), формат отчёта группы (вкл. 5 BUG-HUNTER
секций), verdict-логика. СЛОЙ — состав банды (стартовать 4–6 доменных групп), coverage
taxonomy, маршрутизация.

**zanuda:** ЯДРО — QA-contract («не выглядеть занятым»), closure-gates (вкл. same
reproducer & root cause), probe/full-дисциплина, intersection-мышление. СЛОЙ — источники
истины (свои аудит-доки), харнесс-код (порт), сущности parity-спека.

**Pushkin:** ЯДРО — всё, вкл. guardianship и docs-freshness. СЛОЙ — структура wiki, источники.

**Dobivatel:** ЯДРО — всё (мандат, safety, hygiene-sweep). СЛОЙ — пути, имена веток-конвенций.

**zemlemer:** ЯДРО — методика KLM-GOMS / Touch-Level Model (атомарные операторы K/P/H/M/T…
с эмпирическими временами), эвристики Nielsen 10 + Norman 7 + WCAG POUR, продуктовая карта
per-роль, приоритизация RICE/ICE, iron-rule «измеряй, не угадывай» (число = воспроизводимый
браузерный замер, не оценка), data-sacred (Cancel/Discard после замера; одноразовые сущности
префиксом). СЛОЙ — routes/роли/сценарии целевого продукта (как у semiglazka/renata),
идеал-минимумы флоу, дизайн-система/brand.

**xtracker/Пристав:** ЯДРО — паттерн «оператор жизненного цикла тикета» (create/find/view/
edit/comment/transition/assign/close через ЕДИНСТВЕННЫЙ CLI — как Kulibin зовёт `gh`),
idempotency/dedup (data sacred: не плодить и не терять тикеты), секрет-дисциплина (токен
вне репо, не в argv/логах, редакция в выводах), zero-trust verify-after-mutation (перечитать
тикет, не верить коду возврата), эскалация NEEDS_ORACLE на неизвестный enum. СЛОЙ — сам
трекер и его API (URL/queue/тип/приоритет/коды статусов), CLI-инструмент (`xt`), путь к
токену, маппинг severity→priority. **Порт ТОЛЬКО при внешнем трекере**; на GitHub-issues
встроенный `gh` Kulibin'а закрывает потребность — отдельный агент не нужен.

## 7. Карта плейсхолдеров (выполняет `substitute()` в скрипте — Model B)

Framework-контент содержит `{{PLACEHOLDER}}`-токены вместо литералов конкретного проекта;
`agent-team-adapt.sh` заменяет их значениями из `team.params`. **Пустой/`-` параметр → плейсхолдер
ОСТАЁТСЯ** в адаптированных файлах (честный сигнал «локализуй на Шаге 2», а не пустая строка).

| Плейсхолдер | → Параметр |
|---|---|
| `http://localhost:8000` · `localhost:8000` | LIVE_URL (host — без схемы) |
| `KIZIBY/hr_interview` | GH_REPO |
| `/Users/nikolaykoreshkov/Documents/Claude/Projects/hr_interview` · `/Users/nikolaykoreshkov` | PROJECT_ROOT · HOME_DIR |
| `HR Interview FDE` · `HRI` | PROJECT_NAME · PROJECT_KEY |
| `{{DEPLOY_CMD}}` · `Static HTML/CSS/JS, client-side only (no backend); X5 Group Design System; BroadcastChannel/localStorage sync` | DEPLOY_CMD · STACK |
| `{{SSH_TARGET}}` · `{{SSH_HOST}}` | SSH_TARGET (host = часть после `@`) |
| `{{CONTAINER_PREFIX}}` | CONTAINER_PREFIX |
| `{{TEST_EMAIL_DOMAIN}}` · `{{TEST_EMAIL_DOMAIN_ALT}}` | TEST_EMAIL_DOMAIN(_ALT) |
| `{{TEST_PASSWORD}}` | TEST_PASSWORD (лучше из env/secret-store, не в репо) |
| `{{TRACKER_HOST}}` · `{{TRACKER_TOKEN_PATH}}` · `{{GIT_TOKEN_PATH}}` | TRACKER_HOST · TRACKER_TOKEN_PATH · GIT_TOKEN_PATH |
| `{{TRACKER_QUEUE}}` | TRACKER_QUEUE (очередь трекера, §10; spec 002 G6) |
| `{{SSO_PROVIDER}}` · `{{SSO_ISSUER_URL}}` · `{{SSO_ADMIN_GROUP}}` | SSO_PROVIDER · SSO_ISSUER_URL · SSO_ADMIN_GROUP (§11) |

Устав (`docs/constitution.md`) НЕ подставляется — целевой проект пишет свой (из
`docs/constitution.template.md`); в mothership по этому пути живёт собственный устав mothership v1.0.0,
а **reference-пример X5** — `docs/constitution.x5-reference.md` (помечен баннером, исключён из
де-локализации). `ISSUE_BACKEND`/`GIT_REMOTE`/`TRACKER_TOOL` —
параметры режима (§10), не плейсхолдеры; `TRACKER_QUEUE`/`TRACKER_HOST`/`TRACKER_TOKEN_PATH` — и параметры
режима, и плейсхолдеры (см. таблицу выше). На Шаге 2 проверь остаточные `{{...}}` (`grep -rn '{{' .`) — это незаполненный слой.

## 8. DoD адаптации (валидационный чек-лист)

> Маркеры пунктов — контракт onboarding wizard (spec 007). Auto-пункты (`auto:<имя>` в квадратных
> скобках) проверяет фаза dod-check `scripts/agent-team-onboard.sh` (mothership-only): манифест
> имён — строка `DOD_AUTO_MANIFEST` в его шапке; drift-guard `tests/run-tests.sh` сверяет
> МНОЖЕСТВА имён маркеров и манифеста (I-16) — правка состава auto-пунктов без правки скрипта
> (и наоборот) валит тесты. Manual-пункты wizard печатает MANUAL-остатком как честный gap.

- [ ] `[auto:stubs]` Все стабы ≤ ~35 строк, несут маркер `runtime-стаб`, frontmatter == frontmatter канона
- [ ] `[manual]` Version-probe пройден КАЖДЫМ агентом (шаг 4)
- [ ] `[auto:preflight]` `agent-preflight.sh` зелёный в целевом репо (вкл. root_hygiene=clean)
- [ ] `[auto:placeholders]` Остаточные `{{...}}`-плейсхолдеры (карта §7) осознаны: перечислены
      gap-листом как задача Шага 2 (Model B — сигнал локализации, не FAIL)
- [ ] `[manual]` В канонах не осталось: литералов mothership (grep по карте §7), фантомных ссылок
      на несуществующие файлы/агентов, невыполнимых BLOCKING (шаг 3 пройден)
- [ ] `[auto:memory]` Память каждого агента: seed + указатель на MEMORY_CONVENTION
- [ ] `[auto:agents-md]` AGENTS.md: Team Status таблица + routing + правило стабов
- [ ] `[manual]` Aspirational-нормы оформлены как coverage-цели с gap-отчётом, не как гейты
- [ ] `[manual]` Первый прогон каждого агента дал отчёт с «цель × достигнуто × gap» без симуляции
- [ ] `[manual]` **Onboarding Report** создан (Шаг 1.5a, `docs/agent-onboarding/`) и реально использован при локализации
- [ ] `[manual]` `agent-env-audit.sh` прогнан (Шаг 1.5b; wizard исполняет его отдельной фазой env-audit);
      все REQUIRED-инструменты установлены ИЛИ gap явно принят владельцем (REQUIRED-строка отчёта)
- [ ] `[manual]` При `ISSUE_BACKEND=tracker`: `xtracker` в составе, карта `gh`→`xt` (§10) применена в локализации, `xt ping` зелёный, токен вне репо
- [ ] `[manual]` SSO-режим (§11): `SSO_PROVIDER` заполнен (секция AUTH STANDARD в AGENTS.md есть, QA-вход через SSO/байпас определён) ИЛИ осознанно `-` (решение зафиксировано); spec-шаблоны проекта требуют секцию «Authentication & Access»
- [ ] `[auto:adaptation-md]` `Product_agents/ADAPTATION.md` с машиночитаемой строкой `upstream@SHA` (провенанс bootstrap)
- [ ] `[auto:registry]` Запись в `Product_agents/ADAPTATIONS.md` (проект, состав, UPSTREAM_SHA, дата;
      wizard готовит строку-заготовку БЕЗ абсолютных путей — append подтверждает владелец, SEC-1 spec 007)

## 9. Анти-паттерны (всё — реальные находки аудита 2026-06-10)

1. Полнотекстовая runtime-копия канона (дрейф F-2) — только стаб.
2. BLOCKING-правило, невыполнимое в целевой среде (F-4) — только условная форма.
3. Aspirational-норма как гейт (F-8) — девальвирует достижимые правила.
4. Память без лимита/ротации (F-3: 15k строк > контекста) — конвенция с 1-го дня.
5. Фантомные ссылки (несуществующий агент/файл — кейс audit-test-sync).
6. Копия инструкций в entrypoint расписания (стейл SKILL.md «7 глаз» vs канон v2).
7. Перенос доменных ловушек mothership как «правил» (ловушки X5 ≠ ловушки проекта).
8. Sed-замены без ревью: после шага 1 каждый канон ЧИТАЕТСЯ человеком/агентом (шаг 2).
9. `--update-core`, затирающий слой: seed-док ≠ strict-core — авто-перезапись откатывает
   эволюцию адаптации (боевой кейс Ruscoffee 2026-06-10: форк bug-handling новее mothership).
10. Слепой sed `gh`→`xt` при tracker-режиме (§10): маппинг НЕ 1:1 — push/PR остаются на git,
    `gh auth` — это проверка, а не issue-операция. Свопать только issue-операции по карте §10, с ревью (Шаг 2).
11. «Онбординг для галочки»: локализация (Шаг 2) без чтения Onboarding Report = угадывание слоя.
    Сначала Шаг 1.5a (анализ репо), потом локализация — не наоборот.

## 10. Tracker-режим (`ISSUE_BACKEND=tracker`)

По умолчанию команда ведёт тикеты в GitHub-issues (`gh`). Если проект ведёт тикеты во ВНЕШНЕМ
трекере (XTracker, Jira, YouTrack, …), выставь `ISSUE_BACKEND="tracker"` в `team.params` — и
жизненный цикл тикетов пойдёт через агента **xtracker/Пристав** (CLI `xt`), а не `gh issue`.
Код остаётся там, где указывает `GIT_REMOTE` (по умолчанию — origin из `GH_REPO`): трекер ≠ git-хостинг.
Операторская инструкция и подключение нового трекера — `Product_agents/PRISTAV_TRACKER_GUIDE.md`.

**Что делает Bootstrap (Шаг 1) при `ISSUE_BACKEND=tracker`:**
- авто-добавляет `xtracker` в состав (если его нет), бутстрапит канон `Pristav.md` + стаб;
- штампует в скелет `AGENTS.md` секцию «TRACKER MODE» с картой `gh`→`xt` и путём к токену;
- preflight ведёт issue-часть по бэкенду (факт — spec 002 G2, `agent-preflight.sh`): `ISSUE_BACKEND`/
  `TRACKER_TOOL` из ENV или `team.params` корня; при `tracker` — `python3 $TRACKER_TOOL ping`
  (timeout 10 с, вывод через redact токен-подобных строк), gh понижен до зеркального fallback-канала
  (note); ping fail при живом gh → note-фолбэк, оба канала мертвы → WARN (advisory, не FATAL).

**Карта `gh` → `xt` (применяет локализация Шага 2 — осознанно, НЕ глобальным sed):**

| GitHub (`gh`) | Трекер (`xt`) | Примечание |
|---|---|---|
| `gh issue create` | `xt issue create --queue <Q>` | dedup по summary включён по умолчанию |
| `gh issue list` | `xt issue list --queue <Q>` | фильтры `--status/--assignee/--search` |
| `gh issue view N` | `xt issue view KEY` | |
| `gh issue comment N` | `xt issue comment KEY --body-file -` | длинный текст через stdin, не argv |
| `gh issue close N` | `xt issue close KEY` | close = перевод в терминальный статус; verify-after |
| `gh issue edit` (labels/assignee) | `xt issue edit` / `xt issue assign` | enum-коды из `xt meta`, не выдумывать |
| `gh pr create` / `git push` | **остаются на git** (`GIT_REMOTE`) | PR/push не трогаем — трекер их не заменяет |
| `gh auth status` (preflight) | `xt ping` / `xt whoami` | проверка доступа, а не issue-операция |

**НЕ переписывать `gh` глобальным sed** (анти-паттерн №10): свопаются только issue-операции по
этой карте, с ревью. **Zero-trust:** после любой мутации `xt` перечитать тикет (`xt issue view KEY`) —
код возврата не доказательство (канон `Pristav.md` §6). **Секрет:** токен только в
`TRACKER_TOKEN_PATH` (вне репо, chmod 600) или env; никогда в argv/логах/тикетах/коммитах.

## 11. SSO-режим — корпоративная аутентификация (`SSO_PROVIDER`)

Большинство наших продуктов разрабатывается для X5, где стандарт входа — **«X5 Ключ»**
(OAuth 2.0 / OIDC). Доктрина — `Product_agents/SSO_AUTH_GUIDE.md` (seed-док, §2): правило
по умолчанию «есть вход → вход через корпоративный SSO», инварианты реализации, QA-вход,
reference-чеклист внедрения.

**Что делает Bootstrap (Шаг 1) при `SSO_PROVIDER` ≠ `-`:**
- копирует `Product_agents/SSO_AUTH_GUIDE.md` (seed; плейсхолдеры `{{SSO_PROVIDER}}` /
  `{{SSO_ISSUER_URL}}` / `{{SSO_ADMIN_GROUP}}` подставляются из `team.params`);
- штампует в скелет `AGENTS.md` секцию **AUTH STANDARD** (стандарт, доктрина, секрет-дисциплина) —
  агенты видят стандарт при старте каждого прогона (стаб → AGENTS.md);
- сам гайд копируется и при `SSO_PROVIDER="-"` (плейсхолдеры остаются — Model B, §7): секция
  «Authentication & Access» в спеках обязательна в любом проекте, даже как явное «N/A».

**Где стандарт работает дальше:**
- **Требования:** `speckit.specify` / `/pipeline-stage1` требуют секцию `## Authentication & Access`
  в spec.md; `speckit.clarify` включает auth-таксономию; `/pipeline-stage2` Security Reviewer
  проверяет инварианты `SSO_AUTH_GUIDE.md` §4 (PKCE/state/nonce, секреты, роли из каталога,
  ревокация сессий, QA-байпас не активен в проде).
- **Онбординг (Шаг 1.5a):** Onboarding Report фиксирует текущий auth-механизм проекта.
- **Локализация (Шаг 2):** уточнить QA-вход (SSO-форма / тест-байпас), маппинг групп → роли,
  env-имена секретов; устав проекта — рекомендованный инвариант в `SSO_AUTH_GUIDE.md` §7.
- **QA:** browser-агенты входят по `SSO_AUTH_GUIDE.md` §5 (видимая SSO-форма или документированный
  байпас; секреты не публикуются — общее правило AGENTS.md).

## 12. LV_DCP-интеграция (context-индекс: RAG-дисциплина + trace-приёмник)

Проекты на Python с построенным индексом LV_DCP (`.context/cache.db` в корне) получают связку из
двух механизмов — **чтение** (RAG-дисциплина, spec 008 P5) и **наблюдаемость** (trace-приёмник,
spec 010 P7). Детект индексируемости везде единый: наличие `.context/cache.db`. mothership
(bash/markdown) НЕ индексируется — вся связка для него no-op.

**Цепочка связей (строятся при адаптации):**
1. **Онбординг (Шаг 1.5b, `agent-env-audit.sh`):** если lvdcp-MCP есть, а `.context/cache.db` нет —
   печатает `[HINT] lvdcp_scan(path=…)`. Построй индекс до Шага 6 (обучение), иначе стадии идут слепым grep.
2. **Чтение (стадии пайплайна):** `pipeline-stage1` System Analyst (`mode=navigate`) и
   `pipeline-stage3` Tech Lead (`mode=edit`) для индексированного проекта начинают с `lvdcp_pack`
   вместо grep-walk; lvdcp недоступен / `coverage=ambiguous` → фолбэк на Grep/Glob (стадия не виснет).
   Правило — `docs/pipeline-rules.md` (RAG-дисциплина).
3. **Наблюдаемость (после прогона):** `scripts/audit-to-otel.sh <SPEC_DIR> --out <файл>` конвертирует
   `audit.md` прогона → OTLP JSON (OTel GenAI: `invoke_agent`/`execute_tool`/usage-спаны). Приёмник
   строго on-prem (устав I-1): `--sink lvdcp` кормит локальный LV_DCP portfolio
   (`lvdcp_audit_portfolio`), `--endpoint <url>` — только loopback/private (cloud → fail-closed reject).
   Спаривание событий — единый `pair_events` из `deck-lib.pl` (общий с Flight Deck, анти-дрейф).

**Что в поставке адаптаций:** `audit-to-otel.sh` — CORE_SCRIPTS (едет `--update-core`); RAG-строки
команд — runtime-класс (едут `--update-runtime`); детект `.context/cache.db` и приёмник LV_DCP не
требуют новых `team.params`-параметров (локальны, on-prem by construction). Приёмник Langfuse/collector
(если проект поднимет self-hosted) — через `--endpoint` loopback/private + auth в env `OTEL_EXPORTER_OTLP_HEADERS`.