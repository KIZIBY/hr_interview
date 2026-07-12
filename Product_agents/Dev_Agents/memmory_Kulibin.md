# memmory_Kulibin.md — persistent memory (HR Interview FDE)

> Правила памяти: `Product_agents/MEMORY_CONVENTION.md` — читать компакт целиком перед прогоном; лимит 1500 строк; append-only; при превышении — ротация в `memmory_Kulibin_archive/`.

## Bootstrap (2026-07-07)

Адаптировано из LV_AGENT_TEAM upstream@fb73950 (пайплайн: ADAPTATION_PIPELINE.md).
Статус: шаг 2 (доменная локализация) НЕ завершён — первый прогон = калибровка.

## Run journal

### Run journal — 2026-07-12 (fix-pack #6/#7/#8/#9)
Сводка: fixed 4 (#6 #7 #8 #9), skipped 0, blocked 0; commits 3 (4603ca9 #6+#7+#8, d1675d1 #9, 2eca99e e2e/point-checks); НЕ push (verify-gate/close — оркестратор).
Пересечения проверены: обе страницы (interviewer/candidate); оба транспорта синка — BroadcastChannel И localStorage-fallback (проверено /tmp check-fallback: бейдж+зеркало+метка+DISCONNECT работают на fallback); состояния зеркала (пусто/starterCode/после смены задачи/рассинхрон); состояния 375px (пусто/таблица примеров/длинная строка/overtime/оценка — все scrollWidth<=clientWidth). НЕ проверено вживую в GUI-браузере (нет visible-browser в сессии) — прогон через headless Playwright.
Follow-ups заведены: нет (J10 — артефакт тест-скрипта, не продукт; продуктовый код шкалы не трогал во избежание scope-creep вне 4 issue).

Ключевые уроки по codebase:
- sync.js dispatch: типизированные on(type) обработчики идут ПЕРЕД onAny. Ловушка #6: onAny(pingLiveness) перезаряжал бейдж сразу после on(DISCONNECT)→dropLiveness. Фикс — исключить DISCONNECT из onAny. Порядок обработчиков — важный инвариант шины.
- Контракт TYPES append-only: новые типы (HEARTBEAT/DISCONNECT) обратно-совместимы без подъёма PROTOCOL_VERSION — старые вкладки просто не подписаны (dispatch по env.type). Зафиксировал это в комментарии sync.js.
- Зеркало кода: единый источник публикации на стороне кандидата — publishCode() (и debounced input, и task-switch, и SYNC_REQUEST). Пустая строка публикуется осознанно — зеркалу нужен консистентный сигнал.
- #6 heartbeat/watchdog ускоряемы для тестов через window.HRI_LIVENESS_MS/HRI_HEARTBEAT_MS (не трогая дефолтный контракт 3с/8с). Полезный паттерн для будущих таймингов.
- 375px grid overflow: корень — grid-item min-width:auto (не сжимается ниже min-content). min-width:0 на ячейках грида — системный фикс класса, не заплатка на один экран.
- J10 e2e: zero-area радио (.scale input{width:0}) не фокусируется через .focus() в headless Chromium в определённых состояниях; реальная клавнавигация работает (изоляция 3→4). Адаптировал тест к чистому воспроизведению фокуса кликом по label.
- Baseline в этой среде был 39/44 (не 40), т.к. J10 падает в headless как артефакт; после фиксов+адаптации — 44/44 + point-checks 5/5.
