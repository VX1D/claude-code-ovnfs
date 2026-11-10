# shellcheck shell=bash
# Shared by the hook scripts (sourced, not executed).
OVNFS="${OVNFS_BIN:-$(command -v ovnfs || echo "$HOME/.local/bin/ovnfs")}"
STATE="${XDG_STATE_HOME:-$HOME/.local/state}/claude-code-ovnfs"

ovnfs_mount() {
  "$OVNFS" --json --color never status 2>/dev/null | jq -r '.mount // empty'
}

record_checkout() {
  mkdir -p "$STATE"
  echo "$2" >> "$STATE/$1"
}

# Number of changes in checkout $1 that its source folder does not have yet. `ovnfs diff` keeps
# counting changes after they are applied; a dry-run apply does not. Fails when ovnfs does.
unapplied() {
  "$OVNFS" --json --color never apply "$1" --dry-run 2>/dev/null |
    jq -e '(.applied | length) + (.merged | length) + (.conflicts | length)'
}

# Removes checkout $1, first as a snapshot when it holds unapplied changes.
remove_checkout() {
  local pending
  pending="$(unapplied "$1")" || pending=1
  if [ "$pending" -gt 0 ]; then
    "$OVNFS" snap "$1" -m claude-remove --wait >&2
    "$OVNFS" rm "$1" --sticky-snapshots >&2
  else
    "$OVNFS" rm "$1" >&2
  fi
}
