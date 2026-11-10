#!/usr/bin/env bash
# PreToolUse (Edit|Write|MultiEdit|NotebookEdit): edits go through an ovnfs checkout.
# Outside a checkout, an edit inside the session's repository is denied until EnterWorktree runs.
# Inside a checkout, an edit aimed at the checkout's source folder is denied with the path to use.
# Files holding ovnfs conflict markers (left by `ovnfs apply`) can always be edited.
set -uo pipefail
source "$(dirname "$0")/lib.sh"

[ "${OVNFS_CLAUDE_ISOLATE:-1}" != 0 ] || exit 0

in="$(cat)"
cwd="$(jq -r '.cwd // empty' <<<"$in")"
file="$(jq -r '.tool_input.file_path // .tool_input.notebook_path // empty' <<<"$in")"
[ -n "$cwd" ] && [ -n "$file" ] || exit 0
case "$file" in /*) ;; *) file="$cwd/$file" ;; esac
[ -f "$file" ] && grep -q '^>>>>>>> checkout ' "$file" && exit 0
mount="$(ovnfs_mount)"
[ -n "$mount" ] || exit 0

deny() {
  jq -n --arg r "$1" '{hookSpecificOutput: {hookEventName: "PreToolUse", permissionDecision: "deny", permissionDecisionReason: $r}}'
  exit 0
}

case "$cwd/" in
  "$mount"/*)
    name="${cwd#"$mount"/}"
    name="${name%%/*}"
    src="$("$OVNFS" --json --color never ls 2>/dev/null | jq -r --arg n "$name" '.checkouts[]? | select(.name == $n) | .source')"
    [ -n "$src" ] || exit 0
    case "$file/" in
      "$src"/*) deny "This session works in the ovnfs checkout $mount/$name of $src. Edit ${file/#"$src"/"$mount/$name"} instead; the source folder changes only through ovnfs apply." ;;
    esac
    ;;
  *)
    top="$(git -C "$cwd" rev-parse --show-toplevel 2>/dev/null)" || exit 0
    case "$file/" in
      "$top"/*) deny "Changes to $top go through an ovnfs checkout: call EnterWorktree first, then edit the file inside the checkout. If the user explicitly asked to edit in place, tell them to start the session with OVNFS_CLAUDE_ISOLATE=0." ;;
    esac
    ;;
esac
exit 0
