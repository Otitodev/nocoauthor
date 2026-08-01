#!/bin/sh
# Test suite. Uses throwaway repos and --repo only; never touches the
# developer's global core.hooksPath or ~/.git-hooks.

set -u

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
PASS=0
FAIL=0

ok()   { PASS=$((PASS + 1)); printf '  ok   %s\n' "$1"; }
bad()  { FAIL=$((FAIL + 1)); printf '  FAIL %s\n' "$1"; [ $# -gt 1 ] && printf '       %s\n' "$2"; }
is()   { if [ "$2" = "$3" ]; then ok "$1"; else bad "$1" "expected [$3] got [$2]"; fi; }

newrepo() {
  d="$(mktemp -d 2>/dev/null || mktemp -d -t nca)"
  git init -q "$d"
  git -C "$d" config user.email t@example.com
  git -C "$d" config user.name Tester
  printf '%s' "$d"
}

commit_msg() {  # commit_msg <repo> <message>; echoes resulting message
  printf '%s\n' "$2" | git -C "$1" commit -q --allow-empty -F - 2>/dev/null
  # Command substitution at the call site strips trailing newlines for us.
  git -C "$1" log -1 --format=%B
}

echo "nocoauthor test suite"

# ---------------------------------------------------------------- basic strip
R="$(newrepo)"
( cd "$R" && sh "$ROOT/install.sh" --repo >/dev/null 2>&1 )
out="$(commit_msg "$R" "Subject

Co-Authored-By: Claude <noreply@anthropic.com>
Co-Authored-By: Human <h@example.com>")"
case "$out" in
  *Claude*) bad "strips Claude trailer" "$out" ;;
  *Human*)  ok  "strips Claude trailer, keeps human" ;;
  *)        bad "strips Claude trailer" "$out" ;;
esac

# ------------------------------------------------- message that is all trailer
out="$(commit_msg "$R" "Only trailer
Co-Authored-By: Claude <noreply@anthropic.com>")"
is "never produces an empty message" "$out" "Only trailer"

# ------------------------------------------------------------- custom pattern
git -C "$R" config nocoauthor.pattern 'copilot'
out="$(commit_msg "$R" "Custom

Co-Authored-By: Copilot <bot@github.com>")"
is "honours nocoauthor.pattern" "$out" "Custom"
git -C "$R" config --unset nocoauthor.pattern

# ------------------------------------------------------------- escape hatches
git -C "$R" config nocoauthor.enabled false
out="$(commit_msg "$R" "Disabled

Co-Authored-By: Claude <noreply@anthropic.com>")"
case "$out" in
  *Claude*) ok  "nocoauthor.enabled=false disables stripping" ;;
  *)        bad "nocoauthor.enabled=false disables stripping" "$out" ;;
esac
git -C "$R" config --unset nocoauthor.enabled

printf 'Bypass\n\nCo-Authored-By: Claude <noreply@anthropic.com>\n' \
  | NOCOAUTHOR=0 git -C "$R" commit -q --allow-empty -F - 2>/dev/null
out="$(git -C "$R" log -1 --format=%B)"
case "$out" in
  *Claude*) ok  "NOCOAUTHOR=0 bypasses the hook" ;;
  *)        bad "NOCOAUTHOR=0 bypasses the hook" "$out" ;;
esac

# ------------------------------------------- refuses to clobber a foreign hook
R2="$(newrepo)"
mkdir -p "$R2/.git/hooks"
printf '#!/bin/sh\n# foreign\nexit 0\n' > "$R2/.git/hooks/commit-msg"
before="$(git -C "$R2" config --local --get core.hooksPath 2>/dev/null || echo unset)"
( cd "$R2" && sh "$ROOT/install.sh" --repo >/dev/null 2>&1 )
is "refuses to overwrite a foreign hook" \
   "$(head -2 "$R2/.git/hooks/commit-msg" | tail -1)" "# foreign"
after="$(git -C "$R2" config --local --get core.hooksPath 2>/dev/null || echo unset)"
is "refusal leaves config untouched" "$after" "$before"

# ------------------------------------------------------------------ uninstall
( cd "$R" && sh "$ROOT/uninstall.sh" --repo >/dev/null 2>&1 )
if [ -e "$R/.git/hooks/commit-msg" ]; then
  bad "uninstall removes the hook"
else
  ok "uninstall removes the hook"
fi

rm -rf "$R" "$R2" 2>/dev/null

printf '\n%s passed, %s failed\n' "$PASS" "$FAIL"
[ "$FAIL" -eq 0 ]
