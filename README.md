# nocoauthor

A git `commit-msg` hook that strips AI co-author trailers from your commit
messages.

Coding agents append a trailer to every commit they make:

```
Co-Authored-By: Claude <noreply@anthropic.com>
```

Some people want that. Some people don't, and turning it off means finding the
right setting in every tool separately — and hoping each one honours it. This
hook works one layer down, at git itself, so it applies no matter what produced
the commit: an agent, an IDE, or you.

## Install

Pick whichever you like — all three run the same installer.

**npm** (no install needed, works on macOS, Linux and Windows):

```sh
npx git-nocoauthor install
```

**Shell** (no Node required):

```sh
curl -fsSL https://raw.githubusercontent.com/Otitodev/nocoauthor/main/bootstrap.sh | sh
```

**From source:**

```sh
git clone https://github.com/Otitodev/nocoauthor
cd nocoauthor
./install.sh
```

All of these install globally, for every repository. To limit it to the repo
you're standing in, pass `--repo`:

```sh
npx git-nocoauthor install --repo
curl -fsSL https://raw.githubusercontent.com/Otitodev/nocoauthor/main/bootstrap.sh | sh -s -- --repo
./install.sh --repo
```

## Read this before installing globally

Global installation works by setting `core.hooksPath`, and **that setting is
exclusive**: once set, git ignores every repository's own `.git/hooks`
directory. If any of your projects use husky, lefthook, or pre-commit, their
hooks stop firing.

The installer handles this rather than papering over it:

- If `core.hooksPath` is **already set**, it installs into that directory and
  leaves the setting alone. Your existing hooks keep working.
- If it is **not set**, it warns you and asks before setting it.
- If a *different* `commit-msg` hook is already there, it refuses to overwrite
  and tells you. `--force` backs the old one up first.

If you'd rather not touch global config at all, use `--repo`.

## Verify

```sh
git commit --allow-empty -F - <<'EOF'
Test commit

Co-Authored-By: Claude <noreply@anthropic.com>
Co-Authored-By: A Human <human@example.com>
EOF

git log -1 --format=%B
```

The Claude trailer is gone; the human one is untouched.

## Configuration

Choose which trailers get stripped — any extended-regex alternation, matched
case-insensitively against the trailer line:

```sh
git config --global nocoauthor.pattern 'claude|anthropic|copilot|cursor'
```

Default: `claude|anthropic`.

Turn it off without uninstalling:

```sh
git config --global nocoauthor.enabled false
```

Bypass it for a single commit:

```sh
NOCOAUTHOR=0 git commit -m "..."
```

## What it does not cover

Only commit messages pass through this hook. Pull request descriptions don't —
`gh pr create` never calls git's `commit-msg`. If your agent adds a
"Generated with …" line to PR bodies, turn that off in the tool itself. For
Claude Code that's one line in `~/.claude/settings.json`:

```json
{ "includeCoAuthoredBy": false }
```

The two are complementary: the setting stops the trailer being written at all,
and this hook catches anything that slips through from other tools.

## Uninstall

```sh
npx git-nocoauthor uninstall # or, from a clone:
./uninstall.sh               # or: ./uninstall.sh --repo
```

It removes only a hook it recognises as its own, points you at any backup it
made, and unsets `core.hooksPath` only if it created that directory and nothing
else is left in it.

## License

MIT
