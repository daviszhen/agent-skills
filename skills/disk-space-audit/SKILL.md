---
name: disk-space-audit
description: Audit disk usage on a developer machine and reclaim space safely. Use when a disk is full or nearly full, when asked to clean a workspace / Downloads / Documents folder, or when hunting what consumed tens of gigabytes. Combines size inventory, git safety checks, and platform traps (APFS atime, copy-on-write clones, hardlinks, git worktrees, PATH-resident tools) so nothing with unpushed work or a live dependency gets deleted.
---

# Disk Space Audit

Reclaiming space is not the hard part. The hard part is deciding what may be deleted.
Every destructive mistake in practice comes from a confident single-signal rule
("nothing accessed in a week", "git says clean", "it is only a build dir").

## The one rule

**Never delete on a single signal.** Age, size, `git status`, and access time are each
insufficient. A path is deletable only when **all** of these hold:

1. **No live dependency** — not on `$PATH`, not in shell config, no open file handles,
   no process has it as cwd, not a running app bundle.
2. **No unpushed work** — `dirty == 0` **and** every local branch has `unpushed == 0`
   **and** an origin remote exists.
3. **No irreplaceable data** — not user data, not experiment output existing only here.
4. **Reproducible** — re-clonable, re-downloadable, or regenerable by a documented command.
5. **Measured with `df`** — never quote `du` as the amount freed.

If a check cannot be completed, report **"uncertain"**. Uncertainty must be an explicit
outcome, never a silent pass. A tool that fails (empty output, encoding error, permission
denied) invalidates the conclusion; it does not mean "nothing found".

## Phase 0 — Baseline

Record the before-state so the result is measurable:

```sh
df -h /System/Volumes/Data          # macOS data volume; use / elsewhere
df -k /System/Volumes/Data | awk 'NR==2{printf "%.2f GiB used\n",$3/1048576}'
```

Capture the used bytes as a number. Every later claim of "freed N GB" is
`before_used - after_used`, nothing else. Do not sum per-directory `du` values across
phases: concurrent builds and logs write while you work and will corrupt the arithmetic.

## Phase 1 — Inventory

Measure the top level, then drill into the largest entries.

```sh
cd "$TARGET"
du -sh .                                   # total (approximate, see Phase 4 note)
for d in */ .[!.]*/; do d=${d%/}; [ -d "$d" ] || continue
  printf "%8s MB  %s\n" "$(du -sm "$d" | cut -f1)" "$d"; done | sort -rn | head -40
```

Include hidden directories (`.local-*`, `.mo-*`, `.cache`). Local CI harnesses commonly
leave multi-GB working dirs behind and never clean them.

For each large entry, record: size, mtime, whether it is a git repo, whether it is in
`$PATH`, and whether any process holds it.

## Phase 2 — Classify

Sort every candidate into exactly one bucket. Do not merge buckets "because they look alike".

| Bucket | Test |
|---|---|
| **Live** | running app, PATH entry, open handle — never touch |
| **Contains unpushed work** | git with dirty files or unpushed commits — needs a decision, not a deletion |
| **Irreplaceable data** | only copy of user/experiment data — needs explicit confirmation |
| **Regenerable** | build output, caches, dependency dirs, re-clonable repos |
| **Duplicate** | byte-identical copy exists elsewhere |

### Git safety audit (the part that matters)

Check **every local branch**, not just HEAD:

```sh
# WRONG: only inspects the current branch
git rev-list --count HEAD --not --remotes

# WRONG: --all includes refs/tags, producing huge false positives
#        (a repo with thousands of release tags reports tens of thousands "unpushed")
git rev-list --count --all --not --remotes

# RIGHT: per branch, heads only
for b in $(git for-each-ref --format='%(refname:short)' refs/heads); do
  n=$(git rev-list --count "$b" --not --remotes)
  [ "$n" -gt 0 ] && echo "$PWD  $b  unpushed=$n"
done
```

A repository is deletable only if it has an `origin` and every branch reports 0.
No remote means the commits exist only here, regardless of how old the checkout is.

### Worktree rules

- The stash belongs to the **host** repository, not the worktree. Do not use
  `stash > 0` as a reason to keep a worktree; every worktree will report the host's stash.
- For a worktree, require `dirty == 0` and `HEAD` contained in a remote ref:
  `git branch -r --contains "$(git rev-parse HEAD)"`.
- Remove with `git worktree remove <path>`, never `rm -rf`, so the registry stays consistent.
- `git worktree list` includes entries whose directory is gone. Count real ones after
  `git worktree prune`; otherwise the population is overstated (observed 142 entries
  where 26 were prunable).
- `git status` reporting clean does **not** mean the worktree has no data. Ignored
  directories such as `mo-data/`, `logs/`, `data/` can hold tens of GB. Always run
  `git status --porcelain --ignored` and inspect those paths separately.

### Directory vs archive pairs

An extracted directory next to a `.zip`/`.tar.gz` is **not** automatically redundant.
Verify per file, and account for two traps:

- Archive entries often carry a top-level prefix (`pkg/file.txt`) while the extracted
  tree does not — strip the common prefix before comparing.
- ZIPs with legacy Chinese/Japanese filenames store names in CP437/GBK. A naive listing
  fails or produces mojibake; an empty listing is a failure, not "no unique files".

Compare names and MD5 of contents. Delete the archive only when the directory contains
every entry and every hash matches.

## Phase 3 — Verify before deleting

For the final candidate set, run all of:

```sh
# live dependency
echo "$PATH" | tr ':' '\n' | grep -F "$PWD/candidate"
grep -n "candidate" ~/.zshrc ~/.zprofile ~/.bashrc 2>/dev/null

# process usage
lsof +D ./candidate 2>/dev/null
for pid in $(pgrep -u "$USER"); do
  lsof -a -p "$pid" -d cwd -Fn 2>/dev/null | sed -n 's/^n//p'
done | grep -F "$PWD/candidate"

# git state (repo or worktree)
git -C candidate status --porcelain --ignored
git -C candidate log --all --oneline -- .
```

For running application bundles, also check the app's own lock file
(macOS: `~/Library/Application Support/<App>/…lock`) and that the bundle is not the
only installation. Deleting the only installed editor or CLI while it runs is a common,
entirely avoidable accident.

## Phase 4 — Execute in tiers

Order by risk, cheapest first, and stop between tiers to report.

1. **Regenerable caches and CI leftovers** — no VCS, no handles, disposable.
2. **Stale repos that pass the full git audit** — record each `HEAD` before removal.
3. **Worktrees** — `git worktree remove`, then `git worktree prune`.
4. **Data-bearing directories** — only after explicit confirmation, and state exactly
   what is not recoverable.
5. **History bloat** — a separate, riskier operation (see below).

After each tier: `df` again and report `before → after`.

### Reclaiming space inside git history

Large binaries committed a few times can dwarf the working tree (a 15 GB disk image
committed six times produced a 91 GB `.git`). Rewriting history is irreversible when
there is no remote, so:

1. Extend `.gitignore` for the offending patterns.
2. **Untrack first, keep the file**: `git rm --cached <path>` (or `-r --cached <dir>`),
   then commit. This makes the path untracked so the rewrite's final `reset --hard`
   cannot delete or overwrite it. Verify it is still on disk before continuing.
3. Rewrite: `git filter-branch --index-filter 'git rm -r --cached --ignore-unmatch <path>' --prune-empty -- --all`
   (use `git filter-repo` when available). Set `FILTER_BRANCH_SQUELCH_WARNING=1`.
4. Delete the backup refs, or `gc` will not reclaim anything:
   `git for-each-ref refs/original --format='%(refname)' | xargs -n1 git update-ref -d`
5. `git reflog expire --expire=now --all && git gc --aggressive --prune=now`
6. Verify: `git log --all --oneline -- <path>` must return **0 lines**,
   `git fsck` clean, commit count sane, working files intact.

Do not touch the working tree of a repository that another agent or build is actively
using. Check for `.git/index.lock`, recent commits by other authors, and processes whose
cwd is the repo. Wait for quiescence or ask.

## Phase 5 — Record

Leave an auditable trail. For every deletion record:

- path, size, mtime, `HEAD` (for repos/worktrees), remote URL
- the exact criteria that passed, and the criterion that almost failed
- `df` before and after for the tier
- what is **not** recoverable

Write it to a dated file next to the work, not just to chat.

## Platform facts worth knowing

**macOS / APFS**

- `atime` is not maintained. Mount options typically omit atime updates, so
  `atime == mtime` for nearly every directory. "Not accessed in a week" is
  unmeasurable; any tool offering it is really offering "not modified".
- `du` overestimates, sometimes badly, for three distinct reasons:
  - **copy-on-write clones** — sibling directories cloned from one another each report
    full size (observed 3.5× on a database data tree);
  - **hardlinks** — pnpm/node_modules link into a content store; deleting the directory
    only unlinks, so blocks are freed only when the store entry dies (observed 1.9×);
  - **shared packfiles / shared extents** — similar effect.
  Only `df` is authoritative. `du` is an upper bound.
- Process/`ps` may be restricted in a sandbox; `lsof` still works for cwd and handles.

**Docker**

- `docker system df` reports conservative reclaimable values; actual reclaim after
  `image prune -a` can be larger because shared layers finally drop.
- Order: `docker container prune -f` (stopped containers), then `docker image prune -a`
  (unused images; images of running containers are protected), then consider
  `docker volume prune` and `docker builder prune -af`.
- Never prune volumes without checking: named volumes such as dependency or toolchain
  caches are reused across builds.

**PATH-resident tool installs**

Tools installed into a scratch directory and exported from `~/.zshrc`
(`export PATH="$HOME/Downloads/gh…/bin:$PATH"`) look exactly like disposable download
folders. Check `$PATH` and shell config before deleting anything that contains a `bin/`.

## Anti-patterns

- Deleting by `mtime`/`atime` alone. A four-week-old directory can hold dozens of
  unbacked commits; an untouched directory can be the only installed editor.
- Trusting `git status` clean. Ignored data and caches do not appear in it.
- Treating "directory + archive" or "name looks similar" as duplication.
- Summing `du` across phases, or reporting `du` as bytes freed.
- Bulk-deleting many repos in one command with no per-item verification, then
  discovering a missing remote afterwards.
- Continuing a history rewrite while another process commits to the same repository.
- Leaving `.git` at its pre-rewrite size because `refs/original` was never removed.

## Deliverable

A short report with:

1. Baseline `df` and total target size.
2. Table of top consumers with classification (live / unpushed / data / regenerable / duplicate).
3. Tiered delete list, each tier with size and risk.
4. Explicit "keep" list with the reason (unpushed commits, no remote, running app, PATH).
5. `df` before → after and the net figure.
6. What remains reclaimable and the cost of reclaiming it.

Keep the uncertainty visible: list what could not be verified and why.
