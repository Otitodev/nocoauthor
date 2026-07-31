# CLAUDE.md

See [AGENTS.md](AGENTS.md) — single source of truth for how to work in this
repo. Read it before touching `hooks/commit-msg` or `install.sh`.

Claude Code specifics:

- Do not add `Co-Authored-By` lines to commits here. A repo whose purpose is
  stripping them should not ship a history full of them. Set
  `"includeCoAuthoredBy": false` in `~/.claude/settings.json` rather than
  relying on this repo's own hook to clean up after you.
- Do not run `./install.sh` without `--repo` while developing. The global path
  rewrites your real `core.hooksPath`.
