---
name: ovnfs
description: Working in ovnfs copy-on-write checkouts, which back every worktree in this environment. Use when isolating changes (EnterWorktree, subagents with isolation "worktree"), reviewing what a checkout changed, merging a checkout back into its source folder, resolving apply conflicts, or cleaning up checkouts and snapshots.
---

# ovnfs checkouts

A checkout is a copy-on-write view of a folder at `<mount>/<name>` (`ovnfs status` prints the mount). The source
folder is not touched until `ovnfs apply`.

## Isolate

- Call EnterWorktree, or give a subagent `isolation: "worktree"`. The WorktreeCreate hook opens `<mount>/cc-<name>`
  and the session continues there. Never run `git worktree add`.
- `ovnfs ls` lists open checkouts and snapshots.

## Review

- `ovnfs diff <name>` lists changed source paths; `ovnfs diff <name> -p` prints a unified diff.
- Show the user the diff before merging.

## Merge

1. `ovnfs apply <name> --dry-run` reports what would be applied, merged or conflict.
2. With the user's approval: `ovnfs apply <name>`.
3. Exit status 1 means conflicts: the source files get markers (`<<<<<<< folder`, `=======`,
   `>>>>>>> checkout <name>`). Edit those files in the source folder (the edit guard allows files with markers),
   then run `ovnfs apply <name>` again until it exits 0.

A subagent's checkout is merged the same way, from the main session, after reading its diff.

A checkout opened from inside another checkout (EnterWorktree or a subagent started there) begins with that checkout's
current files, and its source is the original folder: its diff and `apply` include the outer checkout's changes.

## Leave

- After applying: ExitWorktree with `discard_changes: true`. The WorktreeRemove hook removes the checkout; changes
  that were not applied are kept as a snapshot labelled `claude-remove`.
- Restore a snapshot: `ovnfs new --from <snapshot>`. Drop it: `ovnfs drop <snapshot>`.
- When the session ends, the SessionEnd hook removes the subagent checkouts it opened that have no changes. Checkouts
  with changes stay open until they are applied or removed.
