# disk-space-audit

A portable skill for auditing disk usage on a developer machine and reclaiming space
**without deleting unpushed work, live tools, or the only copy of experiment data.**

The hard part of disk cleanup is not finding large directories. It is deciding what may
be deleted. Every real incident in practice comes from a confident single-signal rule:
"nothing accessed in a week", "git says clean", "it is just a build directory".

## Install

DSH / Claude-style skill directories all use the same layout — a directory containing
`SKILL.md`:

```sh
# DSH and most agent runtimes
cp -r disk-space-audit ~/.agents/skills/
# or, if your runtime reads this location
cp -r disk-space-audit ~/.claude/skills/
```

The skill is then discovered by name (`disk-space-audit`) and loaded on demand.

## Contents

| File | Purpose |
|---|---|
| `SKILL.md` | The workflow: baseline → inventory → classify → verify → execute → record, plus the rule set and platform traps |
| `scripts/space-inventory.sh` | Fast size inventory of a directory's children, flagging `PATH`, shell-config, open-handle and git entries |
| `scripts/git-safety-audit.sh` | Per-directory verdict (`DELETE` / `KEEP` / `NOTGIT`) from dirty state, per-branch unpushed commits, remote presence and live dependencies |

## Quick start

```sh
cd /path/to/inspect
~/.agents/skills/disk-space-audit/scripts/space-inventory.sh . 500
~/.agents/skills/disk-space-audit/scripts/git-safety-audit.sh .
```

`space-inventory.sh [ROOT] [MIN_MB] [--check-open]`
`git-safety-audit.sh [ROOT] [--tsv] [--check-open]`

Both are read-only reports. Neither deletes anything.

## What the rule set encodes

These are not theoretical. Each corresponds to a case where a naive rule would have
destroyed something:

- **`atime` is unreliable on APFS** — directories commonly report `atime == mtime`.
  "Not accessed in a week" is unmeasurable; it silently means "not modified".
- **`du` overestimates** — copy-on-write clones report full size per copy (observed
  3.5×), pnpm/node_modules hardlinks keep blocks alive after unlinking (observed 1.9×).
  Only `df` before/after is authoritative.
- **`git rev-list HEAD --not --remotes` inspects one branch only**; use per-branch counts.
- **`git rev-list --all --not --remotes` includes tags** and reports enormous false
  positives on repositories with many release tags.
- **A worktree's stash belongs to the host repository** — do not use it as a keep reason.
- **`git status` clean does not mean no data** — ignored `mo-data/`, `logs/`, `data/`
  directories can hold tens of GB.
- **`git worktree list` overstates the population** — prune before counting.
- **Directory + archive is not automatically duplication** — verify per file, strip
  archive path prefixes, and handle GBK/CP437 filenames in ZIPs.
- **Tools installed into scratch directories look disposable** — check `$PATH` and shell
  config before deleting anything containing a `bin/`.
- **A running application bundle can live outside `/Applications`** — check open handles
  and app lock files.
- **A failed tool must not read as a clean result** — an empty archive listing or a
  `sort: Illegal byte sequence` invalidates the conclusion. Uncertainty must be explicit.
- **`df` values cannot be summed across time** — concurrent builds write while you clean.

## Portability

Written for bash on macOS and Linux. macOS-specific calls fall back gracefully
(`stat -f` → `stat -c`). `du -k -d 1` is supported by both BSD and GNU du; note that
BSD du treats `-s` and `-d` as mutually exclusive.

Docker notes in `SKILL.md` are macOS/Linux agnostic.

## License

Public domain / CC0. Adapt freely.
