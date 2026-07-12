# Git Publish Runbook For Agents

Документ обязателен для агентов, которые меняют репозиторий и должны публиковать результат в `main`, комментировать или закрывать GitHub issues.

## Почему push/resolve ломается

Codex часто работает не в обычной ветке, а в linked worktree с detached `HEAD`.

Для Codex App это нормальная модель работы автоматизаций. Официальная документация Codex Automations говорит, что для Git repositories automation может работать либо в local project, либо в dedicated background worktree; worktree нужен, чтобы изолировать изменения автоматизации от незавершенной локальной работы. Официальная страница Codex App также описывает built-in worktree support: несколько агентов работают в изолированных копиях одного repo, а пользователь может проверять изменения отдельно от локального git state.

Полезные ссылки:

- https://developers.openai.com/codex/app/automations
- https://developers.openai.com/codex/app/worktrees
- https://developers.openai.com/codex/concepts/sandboxing

В таком режиме файл `.git` в рабочей папке содержит ссылку вида:

```text
gitdir: /Users/.../HRI/.git/worktrees/HRI3
```

Часть git-команд пишет служебные файлы не в текущий checkout, а в этот внешний gitdir. В sandbox это может падать:

```text
cannot open .../.git/worktrees/HRI3/FETCH_HEAD: Operation not permitted
```

Отдельная проблема - сеть. Если GitHub/DNS недоступны, команды падают так:

```text
Could not resolve host: github.com
error connecting to api.github.com
```

Это не означает, что правка плохая. Это означает, что агент не имеет надежного publish channel в текущем запуске.

## Общее правило

Issue можно закрывать только после трех фактов:

1. Коммит опубликован в `origin/main`.
2. Remote SHA проверен после push.
3. В issue оставлен комментарий: что сделано, commit SHA, проверки, остаточные ограничения.

Если любой пункт не выполнен, issue не закрывать. Нужно записать blocker в память агента и automation memory.

## Безопасная публикация

Перед началом работы или перед закрытием issue можно быстро проверить состояние агентского Git/GitHub контура:

```bash
bash scripts/agent-preflight.sh
```

Preflight не меняет репозиторий. Он показывает текущий worktree, gitdir, `HEAD`, локальный `origin/main`, настоящий remote SHA через `ls-remote`, возможность fast-forward publish и состояние `gh auth`.

Для `KIZIBY/hr_interview` preflight также проверяет GitHub issue contour: `gh issue list` на чтение issues, repo permissions через GitHub API и вероятную возможность issue write/triage. Если preflight показывает `gh_auth=failed`, `gh_issues_read=failed` или `gh_issues_write_likely=not_confirmed`, агент не должен считать, что сможет смотреть, комментировать, закрывать или переоткрывать тикеты.

## Работа с GitHub тикетами

Любой агент, который работает с тикетами, сначала выполняет:

```bash
bash scripts/agent-preflight.sh origin main
```

После этого:

```bash
gh issue list --repo KIZIBY/hr_interview --state open --limit 100
gh issue view <number> --repo KIZIBY/hr_interview --comments
```

Создание, комментарий, close или reopen считаются выполненными только после успешного ответа GitHub API/CLI/connector. Если connector возвращает ошибку, но `gh` работает, использовать `gh` как fallback и записать это в память агента. Если и connector, и `gh` недоступны, не закрывать issue и не писать в отчете, что тикет обновлен.

Перед созданием нового issue обязательно искать дубликаты:

```bash
gh issue list --repo KIZIBY/hr_interview --state open --search "<ключевые слова>"
```

Repo changes и GitHub issue closure связываются так: сначала published `origin/main` SHA, затем комментарий в issue с SHA/проверками/остаточными ограничениями, затем close/update issue. Локальный коммит без verified remote SHA не является resolved.

В linked worktree не начинать с `git fetch`, если sandbox уже показывал `FETCH_HEAD: Operation not permitted`.

Если `git add`, `git commit`, `git fetch` или `git update-ref` падают на `index.lock`, `HEAD.lock`, `FETCH_HEAD` или `COMMIT_EDITMSG` во внешнем `.git/worktrees/...`, сначала локализовать gitdir текущего worktree:

```bash
bash scripts/agent-localize-gitdir.sh
```

Скрипт переносит mutable gitdir state в `.codex-worktree-git/` внутри текущего checkout и оставляет общий object store прежним. Эта папка игнорируется git.

Если `.git` pointer-файл тоже read-only, скрипт не сможет переключить worktree автоматически. В этом случае использовать wrapper:

```bash
bash scripts/agent-git.sh status
bash scripts/agent-git.sh add <files>
bash scripts/agent-git.sh commit -m "..."
```

`agent-publish-main.sh` сам использует `.codex-worktree-git/`, если она уже создана.

Использовать общий скрипт:

```bash
bash scripts/agent-publish-main.sh
```

Что делает скрипт:

- читает remote `main` через `git ls-remote`, не записывая `FETCH_HEAD`;
- проверяет, что локальный `HEAD` содержит настоящий remote SHA из `ls-remote`, а не только потенциально stale локальный `origin/main`;
- пушит `HEAD:main` только если remote SHA не ушел вперед относительно известной локальной базы;
- после push заново читает remote SHA и сравнивает с `HEAD`;
- после успешной проверки обновляет локальный remote-tracking ref `refs/remotes/origin/main`, чтобы следующий запуск автоматизации не видел stale state;
- отказывается от публикации, если GitHub недоступен или remote ушел вперед.

## Если remote ушел вперед

Не делать force-push.

Нужен один из безопасных путей:

1. Запустить новый Codex worktree от свежего `origin/main` и заново применить только свои изменения.
2. Выполнить `git fetch origin main` вне sandbox или в окружении, где есть запись в linked gitdir.
3. Пересобрать коммит поверх свежего `main`, затем снова запустить `bash scripts/agent-publish-main.sh`.

## Если GitHub недоступен

Оставить локальный коммит или staged changes, затем записать:

- SHA локального коммита, если он создан;
- точную ошибку (`Could not resolve host`, `api.github.com`, `FETCH_HEAD`);
- какие issues нельзя закрывать до публикации;
- следующий шаг для повторного запуска.

## Для issue-only агентов

Агенты без code changes тоже не должны считать GitHub действие выполненным, если connector/`gh` вернул ошибку. Комментарий, reopen или close считается сделанным только после успешного ответа GitHub API/CLI.