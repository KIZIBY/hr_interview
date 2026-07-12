#!/usr/bin/env bash
# agent-worktree-memory-check.sh — детектор незакоммиченной памяти агентов в worktree
# (data-sacred: инциденты 2026-06-10/-21 — память писалась в worktree и терялась при его удалении).
#
# Протокол спасения — канон Dobivatel.md (Operating Loop, «Worktree memory rescue»): dirty/untracked
# memory-файл диф-инспектируется, уникальный append-only контент портируется в канонический
# memmory_<Agent>.md ДО удаления worktree. Этот скрипт — детерминированный ДЕТЕКТОР для гейта
# «не удаляй worktree с непроверенной памятью»; сам перенос остаётся за агентом (нужна оценка diff).
#
# Usage: bash scripts/agent-worktree-memory-check.sh [repo-root]
# Exit:  0 = чисто (память в worktree не грозит потерей) · 1 = найдена dirty/untracked память ·
#        2 = не git-репозиторий
set -uo pipefail   # НЕ -e: упавший детектор на одном worktree не должен прятать остальные

ROOT="${1:-.}"
git -C "$ROOT" rev-parse --git-dir >/dev/null 2>&1 || { echo "worktree-memory-check: FATAL: $ROOT не git-репозиторий" >&2; exit 2; }

found=0
main_wt="$(git -C "$ROOT" rev-parse --show-toplevel)"
git -C "$ROOT" worktree list --porcelain | awk '/^worktree /{print $2}' | while read -r wt; do
  [ "$wt" = "$main_wt" ] && continue   # основной checkout проверяет обычная гигиена
  dirty="$(git -C "$wt" status --porcelain -- 'Product_agents/' 2>/dev/null | grep -Ei 'mem+ory_|_mem+ory|/mem+ory\.md' || true)"
  if [ -n "$dirty" ]; then
    echo "worktree-memory-check: DIRTY MEMORY в $wt:"
    printf '%s\n' "$dirty" | sed 's/^/  /'
    echo "worktree-memory-check:   → перед удалением worktree портируй уникальный контент в канонический memmory_<Agent>.md (Dobivatel.md, Worktree memory rescue)"
    echo "$wt" >> "${TMPDIR:-/tmp}/wt-mem-found.$$"
  fi
done
[ -s "${TMPDIR:-/tmp}/wt-mem-found.$$" ] && found=1
rm -f "${TMPDIR:-/tmp}/wt-mem-found.$$" 2>/dev/null

if [ "$found" -eq 0 ]; then
  echo "worktree-memory-check: OK — незакоммиченной памяти агентов в worktree нет"
fi
exit "$found"
