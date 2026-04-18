#!/usr/bin/env bash
# diff.sh - Compare ~/.claude/ with backup folder (tracked items only)
# Usage: bash diff.sh
# Shows recursive diff, 3 levels deep, with a summary of all differences

# Load shared config (backup_folder, folders, files, plugin_files from config.yml)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/_config.sh"

SRC="$HOME/.claude"
DST="$BACKUP_FOLDER"

# Use config values
FOLDERS="$SYNC_FOLDERS"
PLUGIN_FILES="$SYNC_PLUGIN_FILES"
FILES="$SYNC_FILES"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'
BOLD='\033[1m'

count_same=0
count_diff=0
count_src_only=0
count_dst_only=0
diff_details=""

# ─────────────────────────────────────────────────────────────────
# compare a single file
# ─────────────────────────────────────────────────────────────────
compare_file() {
  local rel="$1"
  local src="$SRC/$rel"
  local dst="$DST/$rel"

  if [ -f "$src" ] && [ -f "$dst" ]; then
    if diff -q "$src" "$dst" > /dev/null 2>&1; then
      echo -e "  ${GREEN}✓${NC} $rel"
      count_same=$((count_same + 1))
    else
      echo -e "  ${RED}≠${NC} $rel"
      count_diff=$((count_diff + 1))
      diff_details="${diff_details}${diff_details:+$'\n'}≠ $rel"
    fi
  elif [ -f "$src" ]; then
    echo -e "  ${YELLOW}→${NC} $rel  (source only)"
    count_src_only=$((count_src_only + 1))
    diff_details="${diff_details}${diff_details:+$'\n'}→ $rel"
  elif [ -f "$dst" ]; then
    echo -e "  ${YELLOW}←${NC} $rel  (backup only)"
    count_dst_only=$((count_dst_only + 1))
    diff_details="${diff_details}${diff_details:+$'\n'}← $rel"
  fi
}

# ─────────────────────────────────────────────────────────────────
# diff -rq a folder, parse output, limit to 3 levels from folder root
# ─────────────────────────────────────────────────────────────────
compare_folder() {
  local folder="$1"
  local src="$SRC/$folder"
  local dst="$DST/$folder"

  echo -e "  ${BOLD}📁 $folder/${NC}"

  if [ ! -d "$src" ] && [ ! -d "$dst" ]; then
    echo -e "      ${CYAN}⚠ not present in either location${NC}"
    return
  fi

  if [ ! -d "$src" ]; then
    echo -e "      ${YELLOW}← entire folder (backup only)${NC}"
    count_dst_only=$((count_dst_only + 1))
    diff_details="${diff_details}${diff_details:+$'\n'}← $folder/"
    return
  fi

  if [ ! -d "$dst" ]; then
    echo -e "      ${YELLOW}→ entire folder (source only)${NC}"
    count_src_only=$((count_src_only + 1))
    diff_details="${diff_details}${diff_details:+$'\n'}→ $folder/"
    return
  fi

  lines=()
  tmp=$(mktemp)
  diff -rq "$src" "$dst" 2>/dev/null > "$tmp"
  while IFS= read -r line; do
    lines+=("$line")
  done < "$tmp"
  rm -f "$tmp"

  if [ ${#lines[@]} -eq 0 ]; then
    echo -e "      ${GREEN}✓ (identical)${NC}"
    count_same=$((count_same + 1))
    return
  fi

  for line in "${lines[@]}"; do
    case "$line" in
      "Files "*)
        rest="${line#Files }"
        src_file="${rest%% and ${dst}*}"
        rel="${src_file#$src/}"
        depth=$(echo "$rel" | tr -cd '/' | wc -c)
        [ "$depth" -le 2 ] || continue
        echo -e "      ${RED}≠${NC} $rel"
        count_diff=$((count_diff + 1))
        diff_details="${diff_details}${diff_details:+$'\n'}≠ $folder/$rel"
        ;;
      "Only in ${src}"*)
        rest="${line#Only in }"
        dir="${rest%%: *}"
        name="${rest##*: }"
        rel_dir="${dir#$src/}"
        [ "$rel_dir" = "$src" ] && rel_dir=""
        full_rel="${rel_dir:+$rel_dir/}$name"
        depth=$(echo "$full_rel" | tr -cd '/' | wc -c)
        [ "$depth" -le 2 ] || continue
        icon=""
        [ -d "$dir/$name" ] && icon="📁 "
        echo -e "      ${YELLOW}→${NC} ${icon}${full_rel}"
        count_src_only=$((count_src_only + 1))
        diff_details="${diff_details}${diff_details:+$'\n'}→ $folder/$full_rel"
        ;;
      "Only in ${dst}"*)
        rest="${line#Only in }"
        dir="${rest%%: *}"
        name="${rest##*: }"
        rel_dir="${dir#$dst/}"
        [ "$rel_dir" = "$dst" ] && rel_dir=""
        full_rel="${rel_dir:+$rel_dir/}$name"
        depth=$(echo "$full_rel" | tr -cd '/' | wc -c)
        [ "$depth" -le 2 ] || continue
        icon=""
        [ -d "$dir/$name" ] && icon="📁 "
        echo -e "      ${YELLOW}←${NC} ${icon}${full_rel}"
        count_dst_only=$((count_dst_only + 1))
        diff_details="${diff_details}${diff_details:+$'\n'}← $folder/$full_rel"
        ;;
    esac
  done
}

# ─────────────────────────────────────────────────────────────────
# HEADER
# ─────────────────────────────────────────────────────────────────
echo ""
echo -e "${BOLD}${BLUE}═══════════════════════════════════════════════════════════════${NC}"
echo -e "${BOLD}${BLUE}   Claude Profile Diff: ~/.claude/ vs $BACKUP_FOLDER       ${NC}"
echo -e "${BOLD}${BLUE}═══════════════════════════════════════════════════════════════${NC}"
echo ""

# ─────────────────────────────────────────────────────────────────
# FILES
# ─────────────────────────────────────────────────────────────────
echo -e "${BOLD}Files${NC}"
for f in $FILES; do
  compare_file "$f"
done
echo ""

echo -e "${BOLD}Plugin files${NC}"
for f in $PLUGIN_FILES; do
  compare_file "plugins/$f"
done
echo ""

# ─────────────────────────────────────────────────────────────────
# FOLDERS
# ─────────────────────────────────────────────────────────────────
echo -e "${BOLD}Folders (recursive, 3 levels deep)${NC}"
for folder in $FOLDERS; do
  compare_folder "$folder"
  echo ""
done

# ─────────────────────────────────────────────────────────────────
# SUMMARY
# ─────────────────────────────────────────────────────────────────
echo -e "${BOLD}${BLUE}═══════════════════════════════════════════════════════════════${NC}"
echo -e "${BOLD}Summary${NC}"
echo -e "  ${GREEN}✓${NC} $count_same identical"
echo -e "  ${RED}≠${NC} $count_diff different"
echo -e "  ${YELLOW}→${NC} $count_src_only only in ~/.claude/"
echo -e "  ${YELLOW}←${NC} $count_dst_only only in backup"

if [ -n "$diff_details" ]; then
  echo ""
  echo -e "${BOLD}Details:${NC}"
  tmp=$(mktemp)
  echo "$diff_details" > "$tmp"
  while IFS= read -r d; do
    case "$d" in
      "≠"*) echo -e "  ${RED}$d${NC}" ;;
      "→"*) echo -e "  ${YELLOW}$d${NC}" ;;
      "←"*) echo -e "  ${YELLOW}$d${NC}" ;;
      *)    echo "  $d" ;;
    esac
  done < "$tmp"
  rm -f "$tmp"
fi

echo ""
echo -e "${BOLD}${BLUE}═══════════════════════════════════════════════════════════════${NC}"

# ─────────────────────────────────────────────────────────────────
# RECOMMENDATION
# ─────────────────────────────────────────────────────────────────
echo ""
if [ "$count_diff" -eq 0 ] && [ "$count_src_only" -eq 0 ] && [ "$count_dst_only" -eq 0 ]; then
  echo -e "  ${GREEN}✓ Everything is in sync. No action needed.${NC}"
elif [ "$count_src_only" -gt 0 ] && [ "$count_dst_only" -eq 0 ] && [ "$count_diff" -eq 0 ]; then
  echo -e "  ${GREEN}→ Export recommended${NC} — source has items not in backup."
elif [ "$count_dst_only" -gt 0 ] && [ "$count_src_only" -eq 0 ] && [ "$count_diff" -eq 0 ]; then
  echo -e "  ${YELLOW}← Import recommended${NC} — backup has items not in source."
else
  echo -e "  ${RED}⚡ Both sides differ.${NC} Review before export or import."
fi
echo ""
