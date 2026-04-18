#!/bin/sh
# diff.sh - Compare ~/.claude/ with backup folder (tracked items only)
# Usage: sh diff.sh

# Load shared config
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
. "$SCRIPT_DIR/_config.sh"

SRC="$HOME/.claude"
DST="$BACKUP_FOLDER"
FOLDERS="$SYNC_FOLDERS"
PLUGIN_FILES="$SYNC_PLUGIN_FILES"
FILES="$SYNC_FILES"

RED="\033[0;31m"
GREEN="\033[0;32m"
YELLOW="\033[1;33m"
BLUE="\033[0;34m"
CYAN="\033[0;36m"
NC="\033[0m"
BOLD="\033[1m"

count_same=0
count_diff=0
count_src_only=0
count_dst_only=0

DIFF_TMP="$(mktemp)"

trap 'rm -f "$DIFF_TMP"' EXIT INT TERM

print_color() {
    color="$1"
    shift
    printf "%b%s%b" "$color" "$*" "$NC"
}

compare_file() {
    rel="$1"
    src="$SRC/$rel"
    dst="$DST/$rel"

    if [ -f "$src" ] && [ -f "$dst" ]; then
        if diff -q "$src" "$dst" > /dev/null 2>&1; then
            print_color "$GREEN" "  [+] $rel"
            count_same=$(($count_same + 1))
        else
            print_color "$RED" "  [!] $rel"
            count_diff=$(($count_diff + 1))
            echo "diff: $rel" >> "$DIFF_TMP"
        fi
    elif [ -f "$src" ]; then
        print_color "$YELLOW" "  [>] $rel  (source only)"
        count_src_only=$(($count_src_only + 1))
        echo "src: $rel" >> "$DIFF_TMP"
    elif [ -f "$dst" ]; then
        print_color "$YELLOW" "  [<] $rel  (backup only)"
        count_dst_only=$(($count_dst_only + 1))
        echo "dst: $rel" >> "$DIFF_TMP"
    fi
}
compare_folder() {
    folder="$1"
    src="$SRC/$folder"
    dst="$DST/$folder"

    print_color "$BOLD" "  [$folder/]"
    echo ""

    if [ ! -d "$src" ] && [ ! -d "$dst" ]; then
        print_color "$CYAN" "      (!) not present in either location"
        echo ""
        return
    fi

    if [ ! -d "$src" ]; then
        print_color "$YELLOW" "      [<] entire folder (backup only)"
        count_dst_only=$(($count_dst_only + 1))
        echo "dst: $folder/" >> "$DIFF_TMP"
        return
    fi

    if [ ! -d "$dst" ]; then
        print_color "$YELLOW" "      [>] entire folder (source only)"
        count_src_only=$(($count_src_only + 1))
        echo "src: $folder/" >> "$DIFF_TMP"
        return
    fi

    diff_output="$(diff -rq "$src" "$dst" 2>/dev/null)"
    line_count="$(echo "$diff_output" | wc -l)"

    if [ "$line_count" -eq 0 ] || [ -z "$diff_output" ]; then
        print_color "$GREEN" "      [+] (identical)"
        count_same=$(($count_same + 1))
        return
    fi

    echo "$diff_output" | while IFS= read -r line || [ -n "$line" ]; do
        case "$line" in
            "Files "*)
                rest="${line#Files }"
                src_file="${rest%% and ${dst}*}"
                rel="${src_file#$src/}"
                depth=$(echo "$rel" | tr -cd "/" | wc -c)
                if [ "$depth" -le 2 ]; then
                    print_color "$RED" "      [!] $rel"
                    count_diff=$(($count_diff + 1))
                    echo "diff: $folder/$rel" >> "$DIFF_TMP"
                fi
                ;;
            "Only in "*)
                rest="${line#Only in }"
                dir="${rest%%: *}"
                name="${rest##*: }"
                rel_dir="${dir#$src/}"
                [ "$rel_dir" = "$src" ] && rel_dir=""
                full_rel="${rel_dir:+$rel_dir/}$name"
                depth=$(echo "$full_rel" | tr -cd "/" | wc -c)
                if [ "$depth" -le 2 ]; then
                    if [ "$dir" = "$src" ]; then
                        print_color "$YELLOW" "      [>] $full_rel"
                        count_src_only=$(($count_src_only + 1))
                        echo "src: $folder/$full_rel" >> "$DIFF_TMP"
                    else
                        print_color "$YELLOW" "      [<] $full_rel"
                        count_dst_only=$(($count_dst_only + 1))
                        echo "dst: $folder/$full_rel" >> "$DIFF_TMP"
                    fi
                fi
                ;;
        esac
    done
}

echo ""
print_color "$BOLD$BLUE" "============================================================"
echo ""
print_color "$BOLD$BLUE" "   Claude Profile Diff: ~/.claude/ vs $BACKUP_FOLDER"
echo ""
print_color "$BOLD$BLUE" "============================================================"
echo ""

print_color "$BOLD" "Files"
echo ""
for f in $FILES; do
    compare_file "$f"
done
echo ""

print_color "$BOLD" "Plugin files"
echo ""
for f in $PLUGIN_FILES; do
    compare_file "plugins/$f"
done
echo ""

print_color "$BOLD" "Folders (recursive, 3 levels deep)"
echo ""
for folder in $FOLDERS; do
    compare_folder "$folder"
    echo ""
done
print_color "$BOLD$BLUE" "============================================================"
echo ""
print_color "$BOLD" "Summary"
echo ""
print_color "$GREEN" "  [+] $count_same identical"
print_color "$RED" "  [!] $count_diff different"
print_color "$YELLOW" "  [>] $count_src_only only in ~/.claude/"
print_color "$YELLOW" "  [<] $count_dst_only only in backup"

if [ -s "$DIFF_TMP" ]; then
    echo ""
    print_color "$BOLD" "Details:"
    echo ""
    while IFS= read -r entry; do
        type="${entry%%:*}"
        content="${entry#*: }"
        case "$type" in
            diff) print_color "$RED" "  [!] $content" ;;
            src)  print_color "$YELLOW" "  [>] $content" ;;
            dst)  print_color "$YELLOW" "  [<] $content" ;;
        esac
    done < "$DIFF_TMP"
fi

echo ""
print_color "$BOLD$BLUE" "============================================================"
echo ""
echo ""
if [ "$count_diff" -eq 0 ] && [ "$count_src_only" -eq 0 ] && [ "$count_dst_only" -eq 0 ]; then
    print_color "$GREEN" "  [+] Everything is in sync. No action needed."
elif [ "$count_src_only" -gt 0 ] && [ "$count_dst_only" -eq 0 ] && [ "$count_diff" -eq 0 ]; then
    print_color "$GREEN" "  [>] Export recommended -- source has items not in backup."
elif [ "$count_dst_only" -gt 0 ] && [ "$count_src_only" -eq 0 ] && [ "$count_diff" -eq 0 ]; then
    print_color "$YELLOW" "  [<] Import recommended -- backup has items not in source."
else
    print_color "$RED" "  [!] Both sides differ. Review before export or import."
fi
echo ""
