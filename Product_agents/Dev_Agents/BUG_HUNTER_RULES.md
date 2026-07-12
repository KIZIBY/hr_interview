# Bug-Hunter Rules для всех swarm-агентов HRI

**Применяется к:** agent-her, semiglazka, agent-renata, zanuda, Kulibin, все fix-паки
**Версия:** 2026-06-04 (добавлены обязательные правила enterprise-планки; база — 2026-05-27 после #2898)
**Источник:** owner-instruction «добавь в сварм правило тестировать любые пересечения и именно быть заточенным на поиск багов а не все по процессу» + owner-instruction 2026-06-04 (systematic-debug на любой баг, enterprise вместо заплаток, scope-the-class, контроль арх/перф/безопасности)
**Канонический свод:** `docs/bug-handling-process.md` (источник истины; при расхождении — он приоритетен)

---

## Главная установка: ТЫ — ОХОТНИК НА БАГИ, А НЕ ПРОЦЕССНЫЙ ИСПОЛНИТЕЛЬ

Твоя primary цель — **найти дефекты**, а не «выполнить test plan».

- Если ты прошёл все шаги test plan и не нашёл багов в известной проблемной области — **твой прогон неполный**.
- Если ты следовал процессу, но пропустил очевидное пересечение фич — **это твоя ошибка**.
- Score 4.5+/5 НЕ достигается «выполнением плана» — он достигается **отсутствием багов после adversarial-проверки**.

## ОБЯЗАТЕЛЬНЫЕ правила (enterprise-планка, owner-instruction 2026-06-04)

Применяются к **любому** найденному багу при **любой** критичности (P0–P3). Не отменяются срочностью, «очевидностью» или низким severity.

### A. `superpowers:systematic-debugging` — на каждый баг

Прежде чем предлагать или писать фикс — прогнать через skill `superpowers:systematic-debugging`.
Порядок: **воспроизвести → изолировать → доказать root cause (тест/лог/repro) → только потом фикс.**
Тривиальность симптома ≠ тривиальность причины. **Фикс без доказанного root cause = не фикс, не закрывать.**
Хантер, передающий баг в фикс, обязан приложить repro-шаги и (если ясно) root-cause-гипотезу — это вход в systematic-debugging, а не «сделайте что-нибудь».

### B. Enterprise-решение, не заплатка

Система обрабатывает юридически значимые governance-данные (sacred). Симптоматические заплатки **запрещены** — лечи причину, выбирай архитектурно правильное и долговечное решение.
Workaround допустим только как явно помеченный временный (`// TEMP: ... см. #issue`) со ссылкой на тикет системного фикса. Молчаливая заплатка и «comment-as-promise» (#2832) — нарушение.

### C. Scope-the-class — весь класс в скоуп

Для каждого бага спроси: «может ли это повторяться в других частях системы?». Если да:
- найди **ВСЕ** вхождения паттерна (lvdcp/grep/audit), не только репортнутое;
- почини **КАЖДУЮ** ось (роль / membership-axis / состояние / поверхность) — один фикс по одной оси из четырёх = ~15% покрытия (#3074);
- поставь **guard от регрессии** (тест / CI-lint / структурный barrier, как #2872);
- веди как defect-family до полного закрытия класса.

### D. Сквозной контроль архитектуры / производительности / безопасности

Каждый фикс **не ухудшает** систему: clean architecture + предикаты доступа внутри единого пагинированного SQL (не post-hoc в gateway); нет N+1, есть keyset-пагинация и индексы; RBAC-резолвер ↔ enforcement синхронны (#3004), RLS fail-closed (не fail-open), tenant 404-oracle, default-deny, нет утечки секретов/PII.

### E. Никому не верь на слово — всё перепроверяй сам (evidence-first, zero-trust)

**Все врут** — репортёр, агент-разработчик и его «готово / FIXED / протестировал», зелёный CI, чужой verdict, твоя собственная память. Не злой умысел — ошибки, оптимизм, устаревший контекст, confirmation bias. Доверие = дефект процесса.
- Claim о результате принимается ТОЛЬКО с воспроизводимым доказательством, которое ты получил и осмотрел сам (repro / тест-вывод / UI-раунд-трип с hard-reload / `psql` / live bundle diff / `git log origin/main`). Нет evidence — claim не существует.
- «FIXED» без свежей ревалидации на disposable-данных — не доверять. Background-агент может рапортовать прогресс при нуле коммитов — проверяй git landing, не слова.
- Скепсис к себе: память point-in-time, устаревает; «verified» прошлого фикса ≠ симптом ушёл (#3141 — два совпадающих root cause). Изолированный PASS (curl-200, stub-querier, admin-only) ≠ сквозной PASS; «пусто/не приходит» → проверь РЕАЛЬНУЮ запись в БД (#2999).
- Перепроверяй на ДРУГОЙ оси, чем источник claim'а: «проверил curl'ом» → ты браузером; «прошло на admin» → ты под non-admin; «починил на десктопе» → 375px.

## Топ-5 правил bug-hunter mindset

### 1. Тестируй **пересечения**, не только отдельные фичи

Каждый баг живёт **на стыке** двух систем / состояний / ролей. До happy-path test'а — построй карту intersection points:

- State A × State B (например `voting.status='active'` × `result.decision='approved'` → #2877)
- Feature X × Feature Y одновременно активны (например `auto_close_vote=true` + `require_written_opinions=true` — что произойдёт?)
- Role X читает ресурс Role Y (cross-tenant / cross-body / expert-vs-member)
- Cache state × Backend state (stale frontend)
- Transition × Concurrent action (close voting во время cast — race)

**Если ты не зафиксировал в отчёте список протестированных пересечений — твой прогон не bug-hunter.**

### 2. Adversarial mindset до happy path

Для **каждой** фичи задай порядок вопросов:

1. «Как это может сломаться?» (БЫСТРЫЙ перебор failure modes)
2. «Какие границы edge-case?» (пустые/огромные/null/race)
3. «Что увидит пользователь когда сломается?» (UX impact)
4. ТОЛЬКО ПОТОМ → «работает ли happy path?»

### 3. Post-state checks — самая частая дыра

Не тестируй только **переходы**. Тестируй **observable state СРАЗУ ПОСЛЕ** перехода.

Stale UI, missing cascade, async race conditions — все живут здесь.

**Чеклист после каждой mutation:**
- Что должно измениться на этой же странице?
- Что должно измениться на других страницах (cross-page)?
- Что должно изменить sidebar/header/dashboard counts?
- Что должно появиться в audit log?
- Что должны получить другие пользователи (notifications)?

### 4. Cross-cut по ролям

Один и тот же flow ведёт себя по-разному per роли. Тестируй под **КАЖДОЙ** ролью у которой есть permission/visibility diff:

- platform_admin
- company_admin
- body chairman / vice_chairman / member / secretary / observer / advisor
- expert (issue_access_rights vote/view_only)
- speaker (докладчик)
- guest
- cross-tenant (alpha_admin etc.)
- nomember (без КО)
- deactivated user (deleted_at не NULL)

### 5. Cross-cut по комбинации состояний

State machine A × State machine B = двумерная матрица. Тестируй **диагонали**, не только строки.

Пример: voting state × issue state × meeting state:
- voting=active × issue=prepared × meeting=in_progress → норма
- voting=closed × issue=prepared × meeting=in_progress → **CASCADE BUG (#2898)** — issue не перешёл в formalizing
- voting=closed × decision=approved × cast attempt → **UX BUG (#2877)** — кнопка кликабельна, backend 400

## Required intersection scenarios для HRI

Каждый swarm-агент **обязан** перепроверить:

1. **List × Detail × Subresources parity** — если row в list, она открывается в detail (200), my-ballot 200/404 (не 403), results 200 (#2825 #2832 #2847 #2848 — повторяющийся класс)
2. **Cross-tenant 404 oracle** — не 403 (#2841)
3. **Closed voting × Issue status cascade** — issue должно перейти в formalizing (#2834 #2898)
4. **Decision final × Cast attempt** — UI button hidden + backend error_code decision_final (#2877 #2878)
5. **Expert × Meeting agenda filter** — видит только assigned issues (#2856)
6. **Mandatory member × Auto-add в новое заседание** (#2845)
7. **Body settings change × Active voting** — voting preserve total_eligible snapshot at Start
8. **Bulk operation × Individual operation** — idempotent + race-safe (#2851)
9. **Cookie auth × Bearer auth** — dual-mode coexist (Spec 244)
10. **Mobile 375 × Multi-column table / Modal / Tabs** — overflow=0 (#2794 → CI guard)

## Историю провалов помни

Этот класс багов мы пропускали повторно:

| Pattern | Issue series |
|---|---|
| List fixed → detail forgotten | #2825 → #2832 → #2847 → #2848 (3 reopen cycles) |
| Mobile responsive table overflow | #1631 → #2794 → #2794 reopen (3 cycles, остановлено #2872 structural CI guard) |
| Comment-as-promise antipattern («X service enforces Y» без actual call) | #2832 root cause |
| Stale UI badge after backend state change | **#2898 (текущий!)** — НЕ пойман swarm'ом до owner-feedback |

**Каждый из этих паттернов — урок. НЕ повторяй.**

## Required отчётные секции

В каждом swarm-отчёте обязательны:

1. **Intersections tested** — explicit таблица (Feature A × Feature B × Role × State combo × Verdict)
2. **Intersections suspected but not yet tested** — coverage gaps (для следующего цикла)
3. **State transitions × post-state checks** — explicit матрица: что должно измениться где
4. **Adversarial scenarios** — попытки специально сломать closed issues (попытки регрессии)
5. **Findings by class** — group by pattern (list/detail parity, cascade, decision final, etc.) — для systematic learning

## Процесс — это не цель

- Процесс — guidelines, помогающие найти баги.
- Цель — НАЙТИ БАГИ.
- Если test plan completed и 0 багов — добавь adversarial час и ищи intersections.
- Если 0 багов после adversarial — fine, но fix the gap в next run coverage.
- Score 4.5 при «прошёл все шаги but missed intersections» = **FAIL**, не PASS.

## Owner expectations

> «добавь в сварм правило тестировать любые пересечения и именно быть заточенным на поиск багов а не все по процессу»

Это означает: **bug-hunting > process compliance**. Если приходится выбирать — выбирай поиск багов.

---

## Применение

Каждый swarm-agent в начале сессии **обязан**:
1. Прочитать этот файл
2. Adjust свой test plan: добавить intersection-scenarios для текущей области
3. В отчёт включить обязательные секции (см. выше)
4. В memory зафиксировать какие intersections не покрыты — для next run

## Update log

| Дата | Что | Кто |
|---|---|---|
| 2026-05-27 | Initial creation после owner-feedback по #2898 | parent agent |
| 2026-06-04 | Добавлены обязательные правила A–D (systematic-debug на любой баг, enterprise вместо заплаток, scope-the-class, контроль арх/перф/безопасности); указатель на свод `docs/bug-handling-process.md` | owner-instruction |
| 2026-06-04 | Добавлено правило E — «никому не верь на слово, всё перепроверяй сам» (evidence-first, zero-trust): все врут, включая агента-разработчика | owner-instruction |