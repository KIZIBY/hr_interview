# ADAPTATION.md — провенанс адаптации

- Mothership: LV_AGENT_TEAM upstream@fb73950
- Дата bootstrap: 2026-07-07
- Состав: kulibin,renata,semiglazka,pushkin
- ISSUE_BACKEND: github · GIT_REMOTE: -
- Параметры (snapshot):
  # team.params — анкета адаптации команды агентов LV_AGENT_TEAM → hr_interview (шаг 0 пайплайна)
  # Формат: KEY="value" (строго в кавычках). '-' = параметр не применяется (замена пропускается).
  # Полное описание: Product_agents/ADAPTATION_PIPELINE.md §4
  # Bootstrap: upstream LV_AGENT_TEAM@fb73950 (2026-07-07)
  
  PROJECT_NAME="HR Interview FDE"
  PROJECT_KEY="HRI"
  PROJECT_ROOT="/Users/nikolaykoreshkov/Documents/Claude/Projects/hr_interview"
  GH_REPO="KIZIBY/hr_interview"
  LIVE_URL="http://localhost:8000"
  STACK="Static HTML/CSS/JS, client-side only (no backend); X5 Group Design System; BroadcastChannel/localStorage sync"
  TEST_CMD_BACKEND="-"
  TEST_CMD_FRONTEND="-"
  DEPLOY_CMD="-"
  TEST_USERS_DOC="-"
  EVIDENCE_ROOT="docs/audit-evidence"
  AGENT_LANG="ru"
  MODEL="opus"
  AGENTS="kulibin,renata,semiglazka,pushkin"
  
  # --- issue-backend / git (tracker-режим, см. ADAPTATION_PIPELINE.md §10) ---
  # ISSUE_BACKEND: github (тикеты в GitHub-issues, gh) | tracker (внешний трекер через Пристава, xt)
  ISSUE_BACKEND="github"
  # GIT_REMOTE: где живёт код (push/PR). '-' = origin из GH_REPO.
  GIT_REMOTE="-"
  # Следующие 4 нужны ТОЛЬКО при ISSUE_BACKEND="tracker" (иначе игнорируются):
  TRACKER_TOOL="-"
  TRACKER_QUEUE="-"
  TRACKER_TOKEN_PATH="-"
  TRACKER_HOST="-"
  
  # --- корпоративный SSO (§11, доктрина Product_agents/SSO_AUTH_GUIDE.md) ---
  # Продукт — статические HTML-страницы без логина (одна машина, две вкладки): SSO нет.
  # Секция Authentication & Access в спеках остаётся обязательной (как явное N/A).
  SSO_PROVIDER="-"
  SSO_ISSUER_URL="-"
  SSO_ADMIN_GROUP="-"
  
  # --- де-локализация (Model B, §7): значения для плейсхолдеров framework-контента ---
  # Пустой/'-' = плейсхолдер ОСТАЁТСЯ в адаптированных файлах (локализуй осознанно на Шаге 2).
  SSH_TARGET="-"
  CONTAINER_PREFIX="-"
  TEST_EMAIL_DOMAIN="-"
  TEST_EMAIL_DOMAIN_ALT="-"
  TEST_PASSWORD="-"
  GIT_TOKEN_PATH="-"
  HOME_DIR="/Users/nikolaykoreshkov"

Next: шаги 1.5–7 пайплайна (Product_agents/ADAPTATION_PIPELINE.md). Sync: --update-core.
