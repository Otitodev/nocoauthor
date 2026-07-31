#!/bin/sh
# nocoauthor installer
#
#   ./install.sh           install globally (all repos, via core.hooksPath)
#   ./install.sh --repo    install into the current repo's .git/hooks only
#   ./install.sh --force   replace a foreign commit-msg hook (backs it up first)

set -eu

HOOK=commit-msg
MARKER='nocoauthor-hook v'
SRC_DIR="$(cd "$(dirname "$0")" && pwd)"
SRC="$SRC_DIR/hooks/$HOOK"

MODE=global
FORCE=0
for arg in "$@"; do
  case "$arg" in
    --repo)  MODE=repo ;;
    --force) FORCE=1 ;;
    -h|--help) sed -n '2,6p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) echo "unknown option: $arg" >&2; exit 2 ;;
  esac
done

[ -f "$SRC" ] || { echo "error: $SRC not found" >&2; exit 1; }
command -v git >/dev/null 2>&1 || { echo "error: git not on PATH" >&2; exit 1; }

say()  { printf '%s\n' "$*"; }
warn() { printf '!! %s\n' "$*" >&2; }

# ------------------------------------------------- phase 1: resolve, no writes
# Nothing in this phase may modify config or the filesystem, so that a refusal
# below leaves the machine exactly as we found it.
NEEDS_PIN=""
NEEDS_GLOBAL_SET=""

if [ "$MODE" = repo ]; then
  git rev-parse --git-dir >/dev/null 2>&1 || {
    echo "error: not inside a git repository" >&2; exit 1; }
  # Deliberately NOT `rev-parse --git-path hooks` — that resolves through
  # core.hooksPath and would point us at the global directory.
  TARGET_DIR="$(git rev-parse --git-dir)/hooks"
  say "Installing into this repo only: $TARGET_DIR"

  # A hooksPath set anywhere else wins over .git/hooks, so the hook we place
  # would never fire. Note that we'll need to pin it — but don't write yet.
  INHERITED="$(git config --get core.hooksPath 2>/dev/null || true)"
  if [ -n "$INHERITED" ] && [ "$INHERITED" != "$TARGET_DIR" ]; then
    NEEDS_PIN="$INHERITED"
  fi
else
  EXISTING="$(git config --global --get core.hooksPath 2>/dev/null || true)"
  case "$EXISTING" in
    "~/"*) EXISTING="$HOME/${EXISTING#\~/}" ;;
  esac

  if [ -n "$EXISTING" ]; then
    # Someone already owns core.hooksPath. Merge into it; never repoint it.
    TARGET_DIR="$EXISTING"
    say "core.hooksPath is already set to: $TARGET_DIR"
    say "Merging into that directory rather than repointing it."
  else
    TARGET_DIR="$HOME/.git-hooks"
    NEEDS_GLOBAL_SET=1
  fi
fi

DEST="$TARGET_DIR/$HOOK"

# ------------------------------- phase 2: refuse before touching anything else
DO_BACKUP=""
if [ -e "$DEST" ]; then
  if grep -q "$MARKER" "$DEST" 2>/dev/null; then
    say "Existing nocoauthor hook found — upgrading in place."
  elif [ "$FORCE" -eq 1 ]; then
    DO_BACKUP=1
  else
    warn "A different $HOOK hook already exists at:"
    warn "  $DEST"
    warn "Refusing to overwrite it. Either merge nocoauthor's one-liner into"
    warn "that script yourself, or re-run with --force to back it up and"
    warn "replace it."
    warn "Nothing was changed."
    exit 1
  fi
fi

# ------------------------------------------------- phase 3: everything mutating
if [ -n "$NEEDS_GLOBAL_SET" ]; then
  warn "Setting a global core.hooksPath. This OVERRIDES every repository's"
  warn "own .git/hooks. If any of your repos rely on husky, lefthook, or"
  warn "pre-commit, those hooks will stop running until you copy them into"
  warn "$TARGET_DIR. Use './install.sh --repo' instead to avoid this."
  printf 'Continue? [y/N] '
  read -r reply </dev/tty || reply=n
  case "$reply" in
    [Yy]*) ;;
    *) say "Aborted. Nothing changed."; exit 1 ;;
  esac
fi

mkdir -p "$TARGET_DIR"

if [ -n "$NEEDS_GLOBAL_SET" ]; then
  git config --global core.hooksPath "$TARGET_DIR"
  say "Set core.hooksPath = $TARGET_DIR"
fi

if [ -n "$NEEDS_PIN" ]; then
  git config --local core.hooksPath "$TARGET_DIR"
  say "core.hooksPath was '$NEEDS_PIN', which would have shadowed this."
  say "Pinned this repo's local core.hooksPath to $TARGET_DIR."
  say "Note: that also disables any other hooks you inherited from there."
fi

if [ -n "$DO_BACKUP" ]; then
  BACKUP="$DEST.bak.$(date +%Y%m%d%H%M%S)"
  cp "$DEST" "$BACKUP"
  warn "Backed up your previous $HOOK hook to:"
  warn "  $BACKUP"
  warn "It is NO LONGER RUNNING. Merge it into $DEST by hand if you need it."
fi

cp "$SRC" "$DEST"
chmod +x "$DEST" 2>/dev/null || true

say ""
say "Installed: $DEST"
say ""
say "Test it:"
say "  git commit --allow-empty -F - <<'EOF'"
say "  Test commit"
say ""
say "  Co-Authored-By: Claude <noreply@anthropic.com>"
say "  EOF"
say "  git log -1 --format=%B"
say ""
say "Customise which trailers are stripped:"
say "  git config --global nocoauthor.pattern 'claude|anthropic|copilot|cursor'"
