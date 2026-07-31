#!/bin/sh
# nocoauthor uninstaller
#
#   ./uninstall.sh         remove the global hook
#   ./uninstall.sh --repo  remove it from the current repo's .git/hooks

set -eu

HOOK=commit-msg
MARKER='nocoauthor-hook v'

MODE=global
[ "${1-}" = "--repo" ] && MODE=repo

say()  { printf '%s\n' "$*"; }
warn() { printf '!! %s\n' "$*" >&2; }

if [ "$MODE" = repo ]; then
  TARGET_DIR="$(git rev-parse --git-dir)/hooks"
else
  TARGET_DIR="$(git config --global --get core.hooksPath 2>/dev/null || true)"
  case "$TARGET_DIR" in
    "~/"*) TARGET_DIR="$HOME/${TARGET_DIR#\~/}" ;;
  esac
  [ -n "$TARGET_DIR" ] || { say "No global core.hooksPath set; nothing to do."; exit 0; }
fi

DEST="$TARGET_DIR/$HOOK"

if [ ! -e "$DEST" ]; then
  say "No $HOOK at $DEST; nothing to do."
  exit 0
fi

if ! grep -q "$MARKER" "$DEST" 2>/dev/null; then
  warn "$DEST was not installed by nocoauthor. Leaving it alone."
  exit 1
fi

rm -f "$DEST"
say "Removed $DEST"

# Restore the previous hook if --force backed one up.
LATEST_BACKUP="$(ls -1 "$DEST".bak.* 2>/dev/null | tail -1 || true)"
if [ -n "$LATEST_BACKUP" ]; then
  say ""
  say "A pre-nocoauthor hook was backed up at:"
  say "  $LATEST_BACKUP"
  say "Restore it with:  mv \"$LATEST_BACKUP\" \"$DEST\""
fi

# Undo the local pin that `install.sh --repo` may have added, so whatever
# core.hooksPath the repo used to inherit starts applying again.
if [ "$MODE" = repo ]; then
  PINNED="$(git config --local --get core.hooksPath 2>/dev/null || true)"
  if [ "$PINNED" = "$TARGET_DIR" ]; then
    REMAINING="$(ls -1 "$TARGET_DIR" 2>/dev/null | grep -v '\.sample$' | grep -v '\.bak\.' || true)"
    if [ -z "$REMAINING" ]; then
      git config --local --unset core.hooksPath
      say "Unset this repo's local core.hooksPath pin."
    else
      say ""
      say "Left the local core.hooksPath pin in place — other hooks are still"
      say "in $TARGET_DIR."
    fi
  fi
fi

# Only unclaim core.hooksPath if we created the dir and it's now empty.
if [ "$MODE" = global ] && [ "$TARGET_DIR" = "$HOME/.git-hooks" ]; then
  if [ -z "$(ls -A "$TARGET_DIR" 2>/dev/null)" ]; then
    git config --global --unset core.hooksPath
    rmdir "$TARGET_DIR" 2>/dev/null || true
    say "Unset core.hooksPath (directory was empty)."
  else
    say ""
    say "Left core.hooksPath pointing at $TARGET_DIR (other hooks still there)."
  fi
fi
