#!/usr/bin/env bash
# git-safety-audit.sh — decide whether directories may be deleted.
#
# Usage:
#   ./git-safety-audit.sh [ROOT]                 # audit direct children of ROOT (default: .)
#   ./git-safety-audit.sh --tsv [ROOT]           # machine-readable output
#   ./git-safety-audit.sh --check-open [ROOT]    # also scan open file handles (slow)
#
# For every child that is a git repo or worktree, reports:
#   dirty, per-branch unpushed commits, remote, HEAD-on-remote, size, and large data dirs
# and prints a verdict:
#   DELETE   clean, fully pushed, remote exists, not a live dependency
#   KEEP     unpushed work, no remote, live dependency, or unreadable state
#   NOTGIT   plain directory (review data/regenerability separately)
#
# Live dependency means: the absolute path appears in $PATH, in a shell config, or
# (with --check-open) a process holds it. Matching is on the full path, never the
# bare directory name — name matching produces false positives ("duckdb" vs ~/.duckdb).
#
# This is a report, not a gate. Always confirm before deleting.
set -uo pipefail

TSV=0; CHECK_OPEN=0; args=()
for a in "$@"; do
  case "$a" in
    --tsv) TSV=1 ;;
    --check-open) CHECK_OPEN=1 ;;
    *) args+=("$a") ;;
  esac
done
ROOT="${args[0]:-.}"
cd "$ROOT" 2>/dev/null || { echo "cannot cd to $ROOT" >&2; exit 1; }

human() { awk -v b="$1" 'BEGIN{split("B KB MB GB TB",u," ");i=1; while(b>=1024&&i<5){b/=1024;i++} printf "%.1f%s",b,u[i]}'; }

# per-branch unpushed: echo "<max> <branch>"
unpushed_all() {
  local repo="$1" max=0 mb="" b n
  while IFS= read -r b; do
    [ -z "$b" ] && continue
    n=$(git -C "$repo" rev-list --count "$b" --not --remotes 2>/dev/null) || n=0
    if [ "${n:-0}" -gt "$max" ]; then max=$n; mb=$b; fi
  done < <(git -C "$repo" for-each-ref --format='%(refname:short)' refs/heads 2>/dev/null)
  echo "$max $mb"
}

shell_cfg="$HOME/.zshrc $HOME/.zprofile $HOME/.bashrc $HOME/.bash_profile $HOME/.profile"

# live dependency on the FULL path (fast checks)
live_dep() {
  local full="$1" c
  printf '%s\n' "$PATH" | tr ':' '\n' | grep -Fxq "$full" && return 0
  printf '%s\n' "$PATH" | tr ':' '\n' | grep -Fq "$full/" && return 0
  for c in $shell_cfg; do
    [ -f "$c" ] || continue
    grep -Fq "$full" "$c" 2>/dev/null && return 0
  done
  return 1
}

open_tmp=""; cleanup() { rm -f ${open_tmp:+"$open_tmp"}; }; trap cleanup EXIT
if [ "$CHECK_OPEN" -eq 1 ]; then
  open_tmp=$(mktemp)
  { for pid in $(pgrep -u "$USER" 2>/dev/null); do
      lsof -a -p "$pid" -d cwd -Fn 2>/dev/null | sed -n 's/^n//p'
      lsof -p "$pid" -Fn 2>/dev/null | sed -n 's/^n\//\//p'
    done; } 2>/dev/null | sort -u > "$open_tmp"
fi

[ "$TSV" -eq 1 ] && printf "path\tkind\tsizeB\tdirty\tunpushed\tunpushedBranch\tonRemote\tremote\tverdict\treason\n"

for d in */ .[!.]*/; do
  d="${d%/}"
  [ -d "$d" ] || continue
  full="$PWD/$d"
  if   [ -d "$d/.git" ]; then kind=repo
  elif [ -f "$d/.git" ]; then kind=worktree
  else kind=plain; fi

  kb=$(du -sk "$d" 2>/dev/null | cut -f1); kb=${kb:-0}; size=$((kb*1024))

  if [ "$kind" = "plain" ]; then
    [ "$TSV" -eq 1 ] && printf "%s\tplain\t%s\t-\t-\t-\t-\t-\tNOTGIT\tplain directory\n" "$d" "$size"
    [ "$TSV" -eq 0 ] && printf "  %-44s %8s  NOTGIT  (plain dir: review data/regenerability)\n" "$d" "$(human "$size")"
    continue
  fi

  dirty=$(git -C "$d" status --porcelain --untracked-files=all 2>/dev/null | wc -l | tr -d ' ')
  sha=$(git -C "$d" rev-parse HEAD 2>/dev/null)
  if git -C "$d" branch -r --contains "$sha" 2>/dev/null | grep -q .; then onrem=yes; else onrem=no; fi

  verdict=DELETE; reason=""

  if live_dep "$full"; then verdict=KEEP; reason="live dependency (PATH/shell config)"; fi
  if [ -n "$open_tmp" ] && grep -Fq "$full" "$open_tmp" 2>/dev/null; then
    verdict=KEEP; reason="open file handle / process cwd"
  fi

  if [ "$kind" = "worktree" ]; then
    remote="wt-of:$(basename "$(dirname "$(git -C "$d" rev-parse --path-format=absolute --git-common-dir 2>/dev/null)")")"
    # unpushed counts belong to the HOST repository; not a worktree criterion
    unp_disp="-"; ub="-"
    [ "$dirty" != "0" ] && { verdict=KEEP; reason="${reason:+$reason; }dirty=$dirty"; }
    [ "$onrem" != "yes" ] && { verdict=KEEP; reason="${reason:+$reason; }HEAD not on remote"; }
  else
    remote=$(git -C "$d" remote get-url origin 2>/dev/null); [ -z "$remote" ] && remote=NONE
    read -r unp ub <<<"$(unpushed_all "$d")"
    unp_disp="${unp:-?}"
    [ "$remote" = "NONE" ] && { verdict=KEEP; reason="no remote"; }
    [ "$dirty" != "0" ] && { verdict=KEEP; reason="${reason:+$reason; }dirty=$dirty"; }
    [ "${unp:-0}" != "0" ] && { verdict=KEEP; reason="${reason:+$reason; }$unp unpushed on $ub"; }
  fi

  # data-like directories worth naming
  extra=""
  for sub in mo-data logs data build target node_modules; do
    [ -d "$d/$sub" ] || continue
    sub_kb=$(du -sk "$d/$sub" 2>/dev/null | cut -f1)
    [ "${sub_kb:-0}" -gt 102400 ] && extra="$extra $sub($(human $((sub_kb*1024))))"
  done

  if [ "$TSV" -eq 1 ]; then
    printf "%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n" \
      "$d" "$kind" "$size" "$dirty" "$unp_disp" "$ub" "$onrem" "$remote" "$verdict" "${reason:-ok}"
  else
    printf "  %-42s %8s  %-6s dirty=%-5s unpushed=%-5s %-34s %s\n" \
      "$d" "$(human "$size")" "$verdict" "$dirty" "$unp_disp" "$remote" "${reason:-}"
    [ -n "$extra" ] && printf "      data dirs:%s\n" "$extra"
  fi
done
