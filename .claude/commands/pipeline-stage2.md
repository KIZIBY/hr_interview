---
description: "Stage 2 Audit Team: проверка spec и генерация plan.md для HRI. Usage: /pipeline-stage2 SPEC_DIR=specs/NNN-slug"
---

> 🔧 **ADAPTED FROM LV_AGENT_TEAM upstream@fb73950 (2026-07-07)** — механическая адаптация (шаг 1 пайплайна).
> TODO локализации (карта: `Product_agents/ADAPTATION_PIPELINE.md` §6): coverage taxonomy,
> доменные ловушки, маршрутизация, stop-list метки; ссылки на устав = TODO-CONSTITUTION.
> До прохождения шага 2 пайплайна этот канон — ЧЕРНОВИК.

# /pipeline-stage2 — Audit Team

**$ARGUMENTS**

Извлеки SPEC_DIR из аргументов (например `SPEC_DIR=specs/001-auth-module`).

Прочти `$SPEC_DIR/spec.md` и `$SPEC_DIR/reviews/stage-1-creative.md`.

**State-гейт:** `bash scripts/pipeline-state.sh stage-start "$SPEC_DIR" stage-2-audit` (BLOCKED → сначала заверши stage-1). Затем `bash scripts/spec-lint.sh "$SPEC_DIR"` — FAIL → верни фичу на stage-1 (не чини спеку молча внутри аудита). Если существует `docs/pipeline-rules.md` — прочти (project-слой правил, обязателен для аудита).

---

## Ты — Audit Director

**Spawni 5 субагентов параллельно:**

**Security Reviewer** (sonnet): Проверь spec на:
- SQL injection: pgx parameterized queries ($1, $2), нет string concat
- RBAC: каждый endpoint проверяет permissions, нет privilege escalation
- JWT: proper validation, token rotation, refresh token security
- SSO / Authentication & Access (доктрина `Product_agents/SSO_AUTH_GUIDE.md` §3–4): секция в спеке
  есть (или явное N/A); вход через корпоративный SSO {{SSO_PROVIDER}} либо задокументированное
  исключение; Authorization Code (+PKCE S256 для public client), state (CSRF) + nonce +
  audience/replay-guard; redirect URI exact-match; секреты SSO только env/secret-store; роли
  ТОЛЬКО из групп каталога; деактивация в каталоге → ревокация сессий; QA тест-байпас выключен в prod
- gRPC: metadata authentication, не plaintext secrets
- File upload: MIME validation, size limits, path traversal prevention
- NATS: нет sensitive data в subject names
- Audit: все мутации логируются
Severity: CRITICAL/WARNING/INFO.

**Performance Analyst** (sonnet): Сначала NFR-форма (доктрина `Product_agents/NFR_GUIDE.md` §1): каждый NFR = метрика — цель — метод — нагрузка; неквантифицированный NFR («быстро», «как сейчас» без базовой линии) = WARNING, а если фича перф/надёжность-критична — CRITICAL. Затем проверь spec на:
- N+1 queries в pgx (batch queries, joins)
- gRPC call chains (max depth 3, no circular)
- NATS consumer lag и backpressure
- Redis caching strategy (TTL, invalidation)
- PostgreSQL index coverage для частых запросов
- File storage: MinIO presigned URLs, не proxy через Go
- WebSocket connection limits (500 concurrent users)
Severity: CRITICAL/WARNING/INFO.

**Architecture Reviewer** (sonnet): Прочти существующие `services/` и `proto/`. Проверь:
- Clean Architecture: handler → service → repository
- Service boundaries: нет прямого доступа к чужой DB schema
- Proto backward compatibility (не удалять/переименовывать поля)
- NATS topics: hierarchical naming (service.entity.action)
- DI через конструкторы, не глобалы
- Config через envconfig
Severity: CRITICAL/WARNING/INFO.

**AI Reviewer** (sonnet): Если фича затрагивает AI сервисы:
- On-premise only: нет внешних API calls
- RBAC in RAG: retrieval фильтрует по правам пользователя
- Prompt injection: input sanitization
- Timeout handling: LLM может работать долго
- Graceful degradation: AI down → core features work
- Token limits: проверка длины input
Severity: CRITICAL/WARNING/INFO.

**Frontend Reviewer** (sonnet): Если фича затрагивает UI:
- FSD layers: правильный import direction
- TypeScript: нет `any`, строгая типизация
- i18n: все строки через t()
- React Query: нет manual fetch в useEffect
- WebSocket: reconnect logic, error handling
- Accessibility: keyboard navigation, ARIA
Severity: CRITICAL/WARNING/INFO.

---

## Constitution Gate (СВЯЗЫВАЮЩИЙ — issue #3186)

После 5 ревьюеров прогони спеку через процедуру **`docs/constitution-check.md`**: загрузи Часть I `docs/constitution.md` (инварианты I-1…I-16) и для каждого выдай вердикт PASS / N/A / FLAG / NEEDS-INFO по его строке «Как проверить». **Не хардкодь принципы — читай их из конституции (DRY).**

Выведи таблицу вердиктов и итог `MUST-FLAG: N · SHOULD-FLAG: N · NEEDS-INFO: N`.

Запиши итог в state (детерминированный след гейта): `bash scripts/pipeline-state.sh gate "$SPEC_DIR" "MUST-FLAG: N · SHOULD-FLAG: N · NEEDS-INFO: N"`.

**Это связывающий гейт:** любой `MUST-FLAG` (или `NEEDS-INFO` на MUST-инвариант) блокирует переход к stage-3, пока нарушение не устранено в спеке **ИЛИ** не проведена явная versioned-поправка устава (Часть III). Молчаливый обход запрещён (I-11 / I-13).

---

## Синтез и вывод

**`$SPEC_DIR/plan.md`**:
```
## Technical Approach
## Implementation Steps (ordered, numbered)
## Units of Work (независимые юниты: имя — файлы/сервисы — depends-on — convergence-check команда)
## Files to Create/Modify (per service)
## Proto Changes
## DB Migrations (per schema)
## NATS Topics (new/modified)
## Known Risks
```

**Units of Work:** юнит = связный пакет работы с чёткой границей файлов и **своей convergence-check командой** (проверяемый предикат: `go build ./services/x/... && go test ./services/x/...`, `npm run type-check` и т.п.). Мелкая фича = один юнит (секцию можно опустить). После записи plan.md зафиксируй юниты в state: `bash scripts/pipeline-state.sh units-set "$SPEC_DIR" "unit-a,unit-b,..."` — stage-4 механически не стартует, пока каждый юнит не пройдёт свой check (`unit-done`). При `Scope: enterprise` (см. state.md) юниты обязательны.

**`$SPEC_DIR/reviews/stage-2-audit.md`**:
```
## Security Review
## Performance Review
## Architecture Review
## AI Review (if applicable)
## Frontend Review (if applicable)
## Constitution Check (таблица I-1…I-16 + `MUST-FLAG: N`)
## Cross-Debates
## Consolidated Findings (CRITICAL/WARNING/INFO counts)
## Plan Decisions
```

---

## USER APPROVAL GATE

Выведи пользователю:
1. Полное содержимое `$SPEC_DIR/plan.md`
2. Сводку: `CRITICAL: N | WARNING: N | INFO: N`
3. Список всех CRITICAL находок
4. **Constitution Check:** `MUST-FLAG: N` + список всех MUST-FLAG / NEEDS-INFO на MUST (если есть)

**Спроси: Approve / Revise / Abort?**

**Гейт плана (детерминированный):** после записи plan.md прогони `bash scripts/plan-lint.sh "$SPEC_DIR"` — FAIL = нет REQUIRED-секции или **осиротевшие требования** (FR/NFR из spec.md без следа в plan.md/tasks.md): адресуй каждое или перенеси в Out of Scope спеки, повтори линт. К USER APPROVAL выходить только с зелёным plan-lint.

**Learnings:** перед гейтом допиши `$SPEC_DIR/reviews/learnings.md` (`## stage-2`): Interpretations / Deviations / Tradeoffs / Open questions — только непустые.

Ответ владельца зафиксируй в state (без этого stage-3 механически заблокирован):

- **Approve** (разрешён только при `MUST-FLAG: 0` и без NEEDS-INFO на MUST) → `bash scripts/pipeline-state.sh approve "$SPEC_DIR" approved` + `bash scripts/pipeline-state.sh stage-done "$SPEC_DIR" stage-2-audit` → запусти: `/pipeline-stage3 SPEC_DIR=$SPEC_DIR`
- **Revise** → `bash scripts/pipeline-state.sh approve "$SPEC_DIR" revise` → уточни что менять, обнови, повтори audit
- **Abort** → `bash scripts/pipeline-state.sh approve "$SPEC_DIR" abort` → остановись