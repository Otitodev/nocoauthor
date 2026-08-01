#!/bin/sh
# nocoauthor bootstrap — fetches the current release and runs its installer.
#
#   curl -fsSL https://raw.githubusercontent.com/Otitodev/nocoauthor/main/bootstrap.sh | sh
#   curl -fsSL .../bootstrap.sh | sh -s -- --repo
#
# Override the source with NOCOAUTHOR_REPO / NOCOAUTHOR_REF.

set -eu

REPO="${NOCOAUTHOR_REPO:-Otitodev/nocoauthor}"
REF="${NOCOAUTHOR_REF:-main}"
URL="https://codeload.github.com/$REPO/tar.gz/$REF"

for tool in tar git; do
  command -v "$tool" >/dev/null 2>&1 || {
    echo "nocoauthor: '$tool' is required but not installed." >&2; exit 1; }
done

TMP="$(mktemp -d 2>/dev/null || mktemp -d -t nocoauthor)"
trap 'rm -rf "$TMP"' EXIT INT TERM

echo "Fetching $REPO@$REF…"
if command -v curl >/dev/null 2>&1; then
  curl -fsSL "$URL" | tar -xz -C "$TMP"
elif command -v wget >/dev/null 2>&1; then
  wget -qO- "$URL" | tar -xz -C "$TMP"
else
  echo "nocoauthor: need curl or wget to download." >&2
  exit 1
fi

DIR="$(find "$TMP" -mindepth 1 -maxdepth 1 -type d | head -1)"
[ -n "$DIR" ] && [ -f "$DIR/install.sh" ] || {
  echo "nocoauthor: unexpected archive layout." >&2; exit 1; }

# install.sh prompts on /dev/tty, so it still works with stdin tied to the pipe.
sh "$DIR/install.sh" "$@"
