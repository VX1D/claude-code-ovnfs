#!/usr/bin/env bash
# WorktreeRemove: removes the ovnfs checkout at worktree_path, keeping unapplied changes as a
# snapshot (`ovnfs new --from SNAP` restores it). stdin: {"worktree_path"}.
set -euo pipefail
source "$(dirname "$0")/lib.sh"

path="$(jq -r '.worktree_path // empty')"
[ -n "$path" ] || { echo "ovnfs: no worktree_path" >&2; exit 1; }
mount="$(ovnfs_mount)" || mount=""

if [ -z "$mount" ] || [[ "$path/" != "$mount"/* ]]; then
  if git -C "$path" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    git -C "$path" worktree remove --force "$path" 2>/dev/null || true
    exit 0
  fi
  [ -n "$mount" ] || { echo "ovnfs: daemon not reachable; $path not removed" >&2; exit 1; }
  exit 0
fi
name="${path#"$mount"/}"
name="${name%%/*}"

# Undo worktree-create.sh's objects swap so the snapshot sees every commit.
if [ -f "$path/.git" ]; then
  gd="$(sed -n 's/^gitdir: //p' "$path/.git")"
  if [ -f "$gd/ovnfs-shared-objects" ] && [ -d "$gd/objects" ] && [ ! -L "$gd/objects" ]; then
    shared="$(cat "$gd/ovnfs-shared-objects")"
    (cd "$gd/objects" && find . -type f ! -path './info/*' -print0 |
      while IFS= read -r -d '' f; do
        mkdir -p "$shared/$(dirname "$f")"
        [ -e "$shared/$f" ] || cp -p "$f" "$shared/$f"
      done)
    rm -rf -- "$gd/objects"
    ln -s "$shared" "$gd/objects"
    rm -f "$gd/ovnfs-shared-objects"
  fi
fi

remove_checkout "$name"
