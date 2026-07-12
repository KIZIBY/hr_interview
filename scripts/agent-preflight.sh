#!/usr/bin/env bash
set -u

remote="${1:-origin}"
branch="${2:-main}"
status=0

# per-run tmp + trap-очистка: фиксированные /tmp/agent-preflight-* копились мусором и
# сталкивались между параллельными агентами (у команды не один пишущий агент)
tmpdir="$(mktemp -d "${TMPDIR:-/tmp}/agent-preflight.XXXXXX")"
trap 'rm -rf "$tmpdir"' EXIT

note() {
  printf 'agent-preflight: %s\n' "$*"
}

warn() {
  printf 'agent-preflight: WARN: %s\n' "$*" >&2
  status=1
}

repo_root="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
local_gitdir="$repo_root/.codex-worktree-git"
if [ -d "$local_gitdir" ] && [ -f "$local_gitdir/HEAD" ]; then
  export GIT_DIR="$local_gitdir"
  export GIT_WORK_TREE="$repo_root"
fi

if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  warn "not inside a git worktree"
  exit "$status"
fi

repo_root="$(git rev-parse --show-toplevel)"
git_dir="$(git rev-parse --git-dir)"
head_sha="$(git rev-parse HEAD 2>/dev/null || true)"
local_tracking_sha="$(git rev-parse --verify --quiet "$remote/$branch" 2>/dev/null || true)"
dirty_lines="$(git status --short | wc -l | tr -d ' ')"

note "repo=$repo_root"
note "git_dir=$git_dir"
note "head=${head_sha:-missing}"
note "local $remote/$branch=${local_tracking_sha:-missing}"
note "dirty_entries=$dirty_lines"

remote_url="$(git remote get-url "$remote" 2>/dev/null || true)"
if [ -z "$remote_url" ]; then
  warn "remote $remote is missing"
else
  note "remote_url=$remote_url"
fi

remote_line="$(git ls-remote --heads "$remote" "$branch" 2>$tmpdir/lsremote.err || true)"
if [ -z "$remote_line" ]; then
  warn "cannot read $remote/$branch"
  cat $tmpdir/lsremote.err >&2 || true
else
  remote_sha="$(printf '%s\n' "$remote_line" | awk '{print $1}')"
  note "remote $remote/$branch=$remote_sha"
  if [ "$remote_sha" = "$head_sha" ]; then
    note "publish_state=remote_matches_head"
  elif ! git cat-file -e "$remote_sha^{commit}" 2>/dev/null; then
    warn "publish_state=blocked_remote_commit_object_missing_need_fetch"
  elif git merge-base --is-ancestor "$remote_sha" "$head_sha" 2>/dev/null; then
    note "publish_state=head_can_fast_forward_remote"
  else
    warn "publish_state=blocked_remote_not_ancestor_of_head"
  fi
fi

# --- issue-контур: github (gh) или внешний трекер (spec 002 G2, FR-1..4) ---
# ENV-контракт (паттерн AGENT_GITHUB_REPO): ISSUE_BACKEND / TRACKER_TOOL читаются из ENV;
# пустой ENV → фолбэк на team.params в корне репо (формат KEY="value", парсер как в
# agent-team-adapt.sh). Нет ни ENV, ни team.params → github: issue-часть и весь вывод
# байт-в-байт как до spec 002 (NFR-4, обратная совместимость 100%).
tp_param() { sed -n "s/^$1=\"\([^\"]*\)\".*\$/\1/p" "$repo_root/team.params" 2>/dev/null | head -1; }
ISSUE_BACKEND="${ISSUE_BACKEND:-}"
[ -n "$ISSUE_BACKEND" ] || ISSUE_BACKEND="$(tp_param ISSUE_BACKEND)"
[ -n "$ISSUE_BACKEND" ] || ISSUE_BACKEND="github"
TRACKER_TOOL="${TRACKER_TOOL:-}"
[ -n "$TRACKER_TOOL" ] || TRACKER_TOOL="$(tp_param TRACKER_TOOL)"

# Секрет-дисциплина (урок X5 51ca2698): stderr трекера может нести токен-подобные строки —
# redact выполняется ДО любого усечения/вывода (redact()-путь xt.py страхуется и на нашей стороне).
redact_tokens() {
  perl -pe 's/\b(authorization|bearer|token|api[-_]?key)\b(["\x27:=\s]*)\S{8,}/$1$2***/gi; s/[A-Za-z0-9_-]{32,}/***/g'
}

if [ "$ISSUE_BACKEND" = "tracker" ]; then
  note "issue_backend=tracker (issue-часть ведёт трекер; gh — зеркальный fallback-канал)"
  # gh-блок при tracker понижен до «зеркала»: доступность — note, недоступность сама по себе не WARN
  gh_mirror=0
  if command -v gh >/dev/null 2>&1 && gh auth status >/dev/null 2>&1; then
    gh_mirror=1; note "gh_mirror=ok"
  else
    note "gh_mirror=unavailable"
  fi
  tracker_ping=""
  if [ -z "$TRACKER_TOOL" ] || [ "$TRACKER_TOOL" = "-" ]; then
    warn "tracker_tool=not_set (ISSUE_BACKEND=tracker, а TRACKER_TOOL пуст — задай в team.params или ENV)"
  elif ! command -v python3 >/dev/null 2>&1; then
    warn "python3 не найден — tracker ping невозможен"
  else
    tracker_tool="$TRACKER_TOOL"
    case "$tracker_tool" in /*) ;; *) tracker_tool="$repo_root/$tracker_tool";; esac  # FR-3: от repo_root, не от cwd
    if [ ! -f "$tracker_tool" ]; then
      warn "tracker_tool=missing: $tracker_tool"
    else
      note "tracker_tool=$tracker_tool"
      # timeout ≤10 с (NFR-1) без GNU timeout: perl alarm + exec (переносимо, bash 3.2 / macOS)
      if perl -e 'alarm shift; exec @ARGV' 10 python3 "$tracker_tool" ping >"$tmpdir/xt-ping.out" 2>&1; then
        tracker_ping=ok; note "tracker_issues=ok"
      else
        tracker_ping=failed
        note "tracker_issues=failed (вывод ping ниже; токен-подобные строки отредактированы)"
        redact_tokens <"$tmpdir/xt-ping.out" | head -5 | sed 's/^/agent-preflight:   | /' >&2
      fi
    fi
  fi
  # Условная деградация (FR-4, конвенция XTRACKER_FILING §1): ping fail при живом gh — штатный
  # фолбэк (note, status не трогаем); оба канала мертвы → warn (advisory-контракт, не FATAL).
  if [ "$tracker_ping" = "failed" ]; then
    if [ "$gh_mirror" -eq 1 ]; then
      note "tracker_fallback=gh issue create (зеркало живо — тикеты есть куда заводить)"
    else
      warn "tracker_issues=failed и gh-зеркало недоступно — тикеты заводить некуда"
    fi
  fi
else

if command -v gh >/dev/null 2>&1; then
  if gh auth status >$tmpdir/gh.out 2>&1; then
    note "gh_auth=ok"
    repo_full="${AGENT_GITHUB_REPO:-}"
    if [ -z "$repo_full" ] && [ -n "${remote_url:-}" ]; then
      case "$remote_url" in
        https://github.com/*)
          repo_full="${remote_url#https://github.com/}"
          repo_full="${repo_full%.git}"
          ;;
        git@github.com:*)
          repo_full="${remote_url#git@github.com:}"
          repo_full="${repo_full%.git}"
          ;;
        ssh://git@github.com/*)
          repo_full="${remote_url#ssh://git@github.com/}"
          repo_full="${repo_full%.git}"
          ;;
      esac
    fi
    if [ -n "$repo_full" ]; then
      note "github_repo=$repo_full"
      if gh issue list --repo "$repo_full" --limit 1 --json number,title >$tmpdir/issues.json 2>$tmpdir/issues.err; then
        note "gh_issues_read=ok"
      else
        warn "gh_issues_read=failed"
        cat $tmpdir/issues.err >&2 || true
      fi
      repo_permissions="$(gh api "repos/$repo_full" --jq '.permissions' 2>$tmpdir/permissions.err || true)"
      if [ -n "$repo_permissions" ]; then
        note "gh_repo_permissions=$repo_permissions"
        can_triage="$(gh api "repos/$repo_full" --jq '(.permissions.admin or .permissions.maintain or .permissions.push or .permissions.triage)' 2>/dev/null || true)"
        if [ "$can_triage" = "true" ]; then
          note "gh_issues_write_likely=ok"
        else
          warn "gh_issues_write_likely=not_confirmed"
        fi
      else
        warn "gh_repo_permissions=unavailable"
        cat $tmpdir/permissions.err >&2 || true
      fi
    else
      warn "github_repo could not be inferred from remote URL"
    fi
  else
    warn "gh_auth=failed"
    cat $tmpdir/gh.out >&2 || true
  fi
else
  warn "gh CLI is not installed"
fi

fi  # конец issue-контура (tracker | github)

# Root hygiene (audit F-5, 2026-06-10): session artifacts do not live in the repo root.
# Evidence -> docs/audit-evidence/<date>/...; audit-sync inputs -> docs/audit-sources/.
# Vendor PDFs are tolerated; the allowlist below is the only md/txt/json/png/html/csv set.
root_allow='README\.md|CLAUDE\.md|CHANGELOG\.md|OPS_PASSWORD_ROTATION_REQUIRED\.md'
root_artifacts="$(find "$repo_root" -maxdepth 1 -type f 2>/dev/null | sed "s|.*/||" | grep -E "\\.(md|txt|json|png|jpe?g|html|csv|docx|xlsx|zip|log|sql)$" | grep -Evx "($root_allow)" || true)"
if [ -n "$root_artifacts" ]; then
  warn "root_hygiene=violations: $(printf '%s' "$root_artifacts" | tr '\n' ' ')(move to docs/audit-evidence/<date>/)"
else
  note "root_hygiene=clean"
fi

exit "$status"
