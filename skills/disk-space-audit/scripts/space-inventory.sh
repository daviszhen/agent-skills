#!/usr/bin/env bash
# space-inventory.sh — fast size inventory with live-dependency flags.
#
# Usage:
#   ./space-inventory.sh [ROOT] [MIN_MB] [--check-open]
#
# Lists every direct child of ROOT (including hidden) at or above MIN_MB (default 50),
# largest first, annotating entries that must not be deleted:
#   [PATH]   referenced from $PATH
#   [SH]     referenced from ~/.zshrc / ~/.bashrc / ~/.zprofile
#   [OPEN]   a process holds a file or has it as cwd   (only with --check-open; slow)
#   [GIT]    git repo or worktree
#
# One du pass, no per-entry fork. Also prints the df baseline and the listed total.
# NOTE: du overestimates on APFS (copy-on-write clones, hardlinks). Treat it as an
#       upper bound and confirm actual reclaim with df before/after a deletion.
set -uo pipefail

CHECK_OPEN=0
args=()
for a in "$@"; do
  case "$a" in
    --check-open) CHECK_OPEN=1 ;;
    *) args+=("$a") ;;
  esac
done
ROOT="${args[0]:-.}"
MIN_MB="${args[1]:-50}"
cd "$ROOT" 2>/dev/null || { echo "cannot cd to $ROOT" >&2; exit 1; }

DF_TARGET="${DSH_DF_TARGET:-/System/Volumes/Data}"
echo "== baseline =="
df -k "$DF_TARGET" 2>/dev/null | awk 'NR==2{printf "  used %.2f GiB  avail %.2f GiB  cap %s\n",$3/1048576,$4/1048576,$5}'
echo "  target: $(pwd)"

# Single filesystem walk for all direct children.
# NOTE: BSD du treats -s and -d as mutually exclusive, so do NOT pass -s here.
tmp=$(mktemp); srt=$(mktemp); open_tmp=""
cleanup() { rm -f "$tmp" "$srt" ${open_tmp:+"$open_tmp"}; }
trap cleanup EXIT

du -k -d 1 . 2>/dev/null | awk -v min=$((MIN_MB*1024)) 'NF==2 && $1>=min && $2!="."' > "$tmp"
sort -rn "$tmp" > "$srt"

if [ "$CHECK_OPEN" -eq 1 ]; then
  open_tmp=$(mktemp)
  { for pid in $(pgrep -u "$USER" 2>/dev/null); do
      lsof -a -p "$pid" -d cwd -Fn 2>/dev/null | sed -n 's/^n//p'
      lsof -p "$pid" -Fn 2>/dev/null | sed -n 's/^n\//\//p'
    done; } 2>/dev/null | sort -u > "$open_tmp"
fi

shell_cfg="$HOME/.zshrc $HOME/.zprofile $HOME/.bashrc $HOME/.bash_profile $HOME/.profile"

echo
echo "== entries >= ${MIN_MB} MB =="
sum=0
while read -r kb path; do
  [ -z "${path:-}" ] && continue
  d="${path#./}"; d="${d%/}"
  [ -d "$d" ] || continue
  sum=$((sum + kb))

  flags=""
  if printf '%s\n' "$PATH" | tr ':' '\n' | grep -Fxq "$PWD/$d"; then flags="$flags PATH"; fi
  for c in $shell_cfg; do
    [ -f "$c" ] && grep -qF "$PWD/$d" "$c" 2>/dev/null && { flags="$flags SH"; break; }
  done
  if [ -n "$open_tmp" ] && grep -qF "$PWD/$d" "$open_tmp" 2>/dev/null; then flags="$flags OPEN"; fi
  { [ -d "$d/.git" ] || [ -f "$d/.git" ]; } && flags="$flags GIT"

  mtime=$(stat -f '%Sm' -t '%Y-%m-%d' "$d" 2>/dev/null || stat -c '%y' "$d" 2>/dev/null | cut -d' ' -f1)
  printf "  %8s MB  %-11s %-22s %s\n" "$((kb/1024))" "$mtime" "[${flags# }]" "$d"
done < "$srt"

echo
echo "== summary =="
awk -v s="$sum" 'BEGIN{printf "  listed total: %d MB (%.1f GB, du upper bound)\n", s/1024, s/1048576}'
echo "  next: run scripts/git-safety-audit.sh before deleting any GIT entry"
[ "$CHECK_OPEN" -eq 0 ] && echo "  note: open-handle check skipped (add --check-open, slower)"
