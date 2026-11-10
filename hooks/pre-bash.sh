#!/usr/bin/env bash
# PreToolUse (Bash): blocks `git worktree add`, which bypasses the WorktreeCreate hook.
set -uo pipefail

cmd="$(jq -r '.tool_input.command // empty')"
if grep -Eq '(^|[;&|(`]|\$\()[[:space:]]*(sudo[[:space:]]+)?([[:alnum:]_]+=[^[:space:]]*[[:space:]]+)*git([[:space:]]+-[^[:space:]]+([[:space:]]+[^-[:space:]][^[:space:]]*)?)*[[:space:]]+worktree[[:space:]]+add([[:space:]]|$)' <<<"$cmd"; then
  jq -n '{hookSpecificOutput: {hookEventName: "PreToolUse", permissionDecision: "deny",
    permissionDecisionReason: "Worktrees are ovnfs checkouts here: use EnterWorktree instead of git worktree add."}}'
fi
exit 0
