# AGENTS.md

A git `commit-msg` hook that strips AI co-author trailers, plus a safe
installer. Four files, no build, no dependencies.

```
hooks/commit-msg   the hook itself (POSIX sh)
install.sh         global (core.hooksPath) or --repo
uninstall.sh       reverses exactly what install did
```

## Rules

- **POSIX `sh`, not bash.** These run under whatever `/bin/sh` git invokes.
  No arrays, no `[[`, no `local`.
- **Never overwrite a hook we don't own.** Ownership is the `nocoauthor-hook v`
  marker comment in `hooks/commit-msg`. If you change that string, change it in
  `install.sh` (`MARKER`) and `uninstall.sh` too, or upgrades start clobbering.
- **The hook must always `exit 0`.** A non-zero exit aborts the user's commit.
  Swallow every failure; leaving the message untouched is the correct fallback.
- **Never write an empty commit message.** The hook only overwrites `$1` when
  the filtered result is non-empty.

## Three traps that already caused bugs

1. `grep -v` **exits 1 when it filters out every line.** Chaining `&& mv` means
   a message consisting solely of trailers silently passes through unstripped.
   Always `|| :`.
2. `git rev-parse --git-path hooks` **resolves through `core.hooksPath`.** For
   repo-local work use `$(git rev-parse --git-dir)/hooks`, or `--repo` writes
   into the global directory while reporting it wrote locally.
3. **`core.hooksPath` is exclusive and global.** Setting it disables every
   repo's `.git/hooks` — husky, lefthook, pre-commit all stop firing. If it is
   already set, merge into that directory; never repoint it.

`install.sh` is deliberately staged **resolve → refuse → mutate**. Nothing may
write config or files before the refusal check, so a failed install leaves the
machine untouched. Keep it that way when editing.

## Testing

Never test the global install path — it edits the developer's real
`~/.git-hooks` and `core.hooksPath`. Use a throwaway repo and `--repo`:

```sh
R=$(mktemp -d); cd "$R"
git init -q .; git config user.email t@e.com; git config user.name T
/path/to/nocoauthor/install.sh --repo
git commit --allow-empty -F - <<'EOF'
Subject

Co-Authored-By: Claude <noreply@anthropic.com>
Co-Authored-By: Human <h@e.com>
EOF
git log -1 --format=%B    # Claude gone, Human kept
```

Cover: mixed trailers, trailer-only message, `nocoauthor.pattern`,
`nocoauthor.enabled false`, `NOCOAUTHOR=0`, foreign-hook refusal (config must
be unchanged after), `--force` backup, reinstall idempotency, uninstall unpin.

## Scope

Commit messages only. PR descriptions never reach `commit-msg`; suppressing
those is the originating tool's setting, not this hook's job.
