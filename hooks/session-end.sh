#!/usr/bin/env bash
# SessionEnd: Claude Code never calls WorktreeRemove for subagent worktrees. Removes the
# checkouts this session created that are still open and hold no unapplied changes, except the
# one the session runs in. The others stay open for `ovnfs diff` / `ovnfs apply`.
set -uo pipefail
source "$(dirname "$0")/lib.sh"

in="$(cat)"
session="$(jq -r '.session_id // empty' <<<"$in")"
cwd="$(jq -r '.cwd // empty' <<<"$in")"
list="$STATE/$session"
[ -n "$session" ] && [ -f "$list" ] || exit 0
mount="$(ovnfs_mount)"
[ -n "$mount" ] || exit 0

open="$("$OVNFS" --json --color never ls 2>/dev/null | jq -r '.checkouts[]?.name')"
while IFS= read -r name; do
  [ -n "$name" ] || continue
  grep -qxF "$name" <<<"$open" || continue
  case "$cwd/" in "$mount/$name/"*) continue ;; esac
  pending="$(unapplied "$name")" || continue
  [ "$pending" -eq 0 ] || continue
  "$OVNFS" rm "$name" >&2 || echo "ovnfs: could not remove $name" >&2
done < <(sort -u "$list")
rm -f "$list"
exit 0
