#!/usr/bin/env bash
# WorktreeCreate: an ovnfs checkout instead of `git worktree add`.
# stdin: {"session_id", "cwd", "name"}; stdout: the checkout path, nothing else.
set -euo pipefail
exec 3>&1 1>&2
source "$(dirname "$0")/lib.sh"

err="$(mktemp)"
trap 'rm -f "$err"' EXIT

in="$(cat)"
cwd="$(jq -r '.cwd // empty' <<<"$in")"
name="$(jq -r '.name // empty' <<<"$in")"
session="$(jq -r '.session_id // empty' <<<"$in")"
[ -n "$cwd" ] || { echo "ovnfs: no cwd"; exit 1; }
src="$(git -C "$cwd" rev-parse --show-toplevel 2>/dev/null || echo "$cwd")"
slug="$(printf 'cc-%s' "${name:-wt}" | tr '[:upper:]' '[:lower:]' | tr -c 'a-z0-9._-' '-' | tr -s '-' | cut -c1-58)"
slug="${slug%-}"

# Claude Code rejects a gitdir whose `objects` is a symlink, which is how ovnfs shares the
# base's object store. Swap it for a directory that borrows the store via alternates;
# worktree-remove.sh moves new objects back and restores the link.
unlink_objects() {
  local gd shared
  [ -f "$1/.git" ] || return 0
  gd="$(sed -n 's/^gitdir: //p' "$1/.git")"
  [ -L "$gd/objects" ] || return 0
  shared="$(readlink "$gd/objects")"
  rm "$gd/objects"
  mkdir -p "$gd/objects/info" "$gd/objects/pack"
  echo "$shared" > "$gd/objects/info/alternates"
  echo "$shared" > "$gd/ovnfs-shared-objects"
}

try="$slug"
for _ in 1 2 3 4 5; do
  if out="$("$OVNFS" --json --color never new "$src" --name="$try" 2>"$err")"; then
    path="$(jq -r '.checkout.path' <<<"$out")"
    unlink_objects "$path"
    [ -n "$session" ] && record_checkout "$session" "$try"
    echo "ovnfs: checkout $try of $src -> $path"
    echo "$path" >&3
    exit 0
  fi
  grep -q '^exists' "$err" || { cat "$err"; exit 1; }
  try="$slug-$(head -c3 /dev/urandom | od -An -tx1 | tr -d ' \n')"
done
echo "ovnfs: no free name for $slug"
exit 1
