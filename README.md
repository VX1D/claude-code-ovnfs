# claude-code-ovnfs

A Claude Code plugin that makes [ovnfs](https://github.com/stencil-hq/ovnfs) copy-on-write checkouts the way Claude
isolates work. Every worktree Claude Code creates (`EnterWorktree`, subagents with `isolation: "worktree"`,
`claude --worktree`) is an ovnfs checkout, edits to a repository are made inside a checkout, and Claude reviews with
`ovnfs diff` and merges back with `ovnfs apply` after you approve.

## Requirements

- Claude Code 2.1.300 or newer
- ovnfs 0.3 or newer with its daemon running
- `bash`, `git`, `jq`

The hooks run `$OVNFS_BIN`, else `ovnfs` from `PATH`, else `~/.local/bin/ovnfs`.

## Installation

```bash
claude plugin marketplace add VX1D/claude-code-ovnfs
claude plugin install ovnfs@claude-code-ovnfs
```

Remove any `WorktreeCreate` / `WorktreeRemove` hooks of your own from `settings.json` first: two creation hooks would
open two worktrees.

## What it does

| hook | behaviour |
|---|---|
| `WorktreeCreate` | opens an ovnfs checkout `<mount>/cc-<name>` of the repository's top level (any folder works, git or not) |
| `WorktreeRemove` | removes the checkout; changes its source folder does not have yet are kept as a snapshot labelled `claude-remove` |
| `SessionStart` | when the ovnfs daemon is reachable, tells Claude that worktrees are ovnfs checkouts and how to review and merge them |
| `PreToolUse` on `Edit`, `Write`, `MultiEdit`, `NotebookEdit` | outside a checkout, denies edits inside the session's git repository until Claude calls `EnterWorktree`; inside a checkout, denies edits aimed at the source folder and names the path in the checkout; files with ovnfs conflict markers stay editable |
| `PreToolUse` on `Bash` | denies `git worktree add` |
| `SessionEnd` | Claude Code never removes subagent worktrees; removes the ones this session opened that hold no unapplied changes and keeps the rest for review |

The `ovnfs` skill gives Claude the full procedure: isolate, review, merge, resolve conflicts, leave.

A typical session: you ask for a change, Claude calls `EnterWorktree` and edits `<mount>/cc-<name>`, shows
`ovnfs diff <name> -p`, and after your approval runs `ovnfs apply <name>`. Conflicts leave markers in the source
folder and `apply` exits 1; Claude resolves them and applies again.

A checkout opened from inside another checkout starts with that checkout's current files; its source is still the
original folder, so its diff and `apply` include the outer checkout's changes.

## Configuration

| variable | effect |
|---|---|
| `OVNFS_CLAUDE_ISOLATE=0` | edits in place: no edit guard and no isolation instruction; worktrees are still ovnfs checkouts |
| `OVNFS_BIN` | path of the `ovnfs` binary |
| `XDG_STATE_HOME` | where the per-session list of opened checkouts is kept (`claude-code-ovnfs/`) |

## Checkout names

`cc-<name>`, where `<name>` is the worktree name lowercased, other characters replaced by `-`, repeated `-`
collapsed, at most 58 characters. A taken name gets a random suffix (`cc-feature-1a2b3c`).

## Git internals

ovnfs links a checkout's `.git/objects` to an object store shared with its base. Claude Code rejects a gitdir whose
`objects` is a symlink, so `WorktreeCreate` replaces the link with a directory that borrows the shared objects
through `objects/info/alternates`. `WorktreeRemove` copies objects created in the checkout (new commits) back into
the shared store and restores the link before the snapshot is taken.

## Limitations

- File changes made through Bash (`>>`, `sed -i`, …) are not intercepted; outside a checkout they reach the source
  folder. The `SessionStart` instruction asks Claude to enter a worktree before changing files, which it does in
  practice, but it is not enforced.
- Claude Code does not run plugin `WorktreeCreate` hooks for `claude --worktree --tmux`. For that combination, put the
  two worktree hooks in `settings.json` instead, pointing at `hooks/worktree-create.sh` and `hooks/worktree-remove.sh`.

## License

MIT
