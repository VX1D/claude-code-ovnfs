#!/usr/bin/env bash
# SessionStart: tells Claude that worktrees are ovnfs checkouts and how to work with them.
# Prints nothing when the ovnfs daemon is not reachable.
set -uo pipefail
source "$(dirname "$0")/lib.sh"

cat >/dev/null
[ -d "$STATE" ] && find "$STATE" -type f -mtime +7 -delete
mount="$(ovnfs_mount)"
[ -n "$mount" ] || exit 0

isolate=""
if [ "${OVNFS_CLAUDE_ISOLATE:-1}" != 0 ]; then
  isolate="- Edits to files of a git repository are only allowed inside an ovnfs checkout (a hook enforces this): before changing files, call EnterWorktree. Read-only work needs no worktree.
"
fi

context="ovnfs is available. Worktrees here are ovnfs copy-on-write checkouts under $mount/: EnterWorktree, subagents with isolation \"worktree\" and \`claude --worktree\` all create one. They open without copying the folder, git repository or not.
${isolate}- Never run \`git worktree add\`; use EnterWorktree.
- Review a checkout with \`ovnfs diff <name> -p\` (name = the folder under $mount/).
- Merge into the source folder only after the user approves: \`ovnfs apply <name>\`. Exit status 1 means conflicts: markers are left in the source files; resolve them and apply again.
- After applying, leave with ExitWorktree and discard_changes: true. Changes that were not applied are kept as a snapshot when the checkout is removed.
- The ovnfs skill has the details."

jq -n --arg c "$context" '{hookSpecificOutput: {hookEventName: "SessionStart", additionalContext: $c}}'
