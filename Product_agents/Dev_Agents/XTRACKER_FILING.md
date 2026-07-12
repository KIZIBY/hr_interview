# XTracker filing protocol (канон для всех агентов команды)

Status: ДЕЙСТВУЮЩИЙ (v1.1, 2026-07-03 — spec 005: `[Owner]`-префикс для owner-тикетов канала `/intake`; v1.0, 2026-06-25 — базовый протокол переходного периода GitHub→XTracker)

Единый протокол заведения находок в корпоративный XTracker на переходный период GitHub→XTracker (2026-06-25). Каноны агентов ссылаются сюда вместо дублирования команд (анти-дрейф). Подтверждён пилотами HER/Semiglazka/Zemlemer/Renata (BOARD-52/66/67/68).

## Инструмент
- Всегда `python3 scripts/xtracker/xt.py <cmd>` **из корня репозитория** (`git rev-parse --show-toplevel`). Короткого алиаса `xt` в PATH НЕТ — пиши полный путь.
- Очередь команды — `{{TRACKER_QUEUE}}`.

## Авторство (BLOCKING)
- Каждый **summary И тело** начинаются с `[<Имя агента>]` — `[Her]`, `[Semiglazka]`, `[Zemlemer]`, `[Renata]`, `[Kulibin]`, `[Zanuda]`. Это ЕДИНСТВЕННЫЙ признак авторства: reporter в XTracker = общий сервис-аккаунт (`Claude_code_vl`/владелец), по нему авторство НЕ ищется.
- `[<Имя>]` — **первый АВТОРСКИЙ токен** summary; доп-теги (`[pilot-check]`, severity-метки) идут ПОСЛЕ него. Реконсайлер «Пристав» может дописать системный тег `[GH#n]` в самое начало (`[GH#123] [Renata] …`) — это нормально; поиск авторства всегда по подстроке `[<Имя>]`, не по началу строки и не по reporter.
- **Owner-тикеты (канал `/intake`, v1.1):** тикеты, инициированные владельцем, несут префикс `[Owner]` первым токеном summary И body по тем же правилам, что `[<Имя агента>]`; тело — префикс + дословная фраза владельца + дата. Префикс конструирует `scripts/intake.sh` (агентские вызовы того же скрипта — `INTAKE_AUTHOR=<Имя>`); правила dedup/verify-read ниже применяются без изменений.

## Протокол (по шагам)
1. **Пред-шаг (ОБЯЗАТЕЛЬНО): `python3 scripts/xtracker/xt.py ping`.** `ok` → VPN есть, продолжай. Ошибка (нет VPN) → **фолбэк**: заводи в GitHub как раньше (`gh issue create` / `mcp__codex_apps__github__create_issue`), Пристав зеркалит GH→XTracker сам. Нет связи ≠ имитировать успех.
2. **Dedup:** `python3 scripts/xtracker/xt.py issue list --queue {{TRACKER_QUEUE}} --search "<ключевые слова>"`. Сверяй по префиксу `[<Имя>]`, не по reporter. Дубль → коммент, не новый тикет. (`create` дополнительно сам прогоняет dedup → `dedup: checked`.)
3. **Create:** `printf '%s' "$BODY" | python3 scripts/xtracker/xt.py issue create --queue {{TRACKER_QUEUE}} --summary "[<Имя>] <тема>" --type task --priority medium --body-file -`. Тело (`$BODY`) — в формате твоего канона, начинается с `[<Имя>]`; severity/роль/URL — в теле (в трекере хранится `priority`). Лейблы при нужде: `python3 scripts/xtracker/xt.py issue label <KEY> --add <a,b>`.
4. **Verify-read (zero-trust, ОБЯЗАТЕЛЬНО): `python3 scripts/xtracker/xt.py issue view <KEY>`.** Подтверди, что summary и тело начинаются с `[<Имя>]` verbatim. НЕ верь только ответу `create` — перечитай.
5. **Жизненный цикл:** коммент `… issue comment <KEY> --body-file -`; закрытие `… issue close <KEY> --comment "[<Имя>] <итог>"` (дефолтный терминал `done`; CLI сам идёт по workflow `todo→inProgress→done`); reopen `… issue reopen <KEY>`.

## Не-браузерные / инфраструктурные находки
Если обязательная секция формата канона требует артефакт, которого по природе находки нет (напр. `## Скриншот` для CLI/инфра-тикета) — заполняй явным `N/A — <причина>`. «Без всех секций тикет не принимается» НЕ означает запрет `N/A`: запрещены ПУСТЫЕ секции, не честный `N/A`.

## Не дублируй вручную
Двусторонний sync BOARD↔GitHub держит Пристав-реконсайлер (`scripts/xtracker/sync.py`, launchd каждые 20 мин, no-op без VPN). Пиши в ОДИН трекер (XTracker, либо GitHub при VPN-фолбэке) — зеркало сделает Пристав. Не повторяй sync-логику в своём каноне.