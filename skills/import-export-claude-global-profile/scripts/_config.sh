#!/bin/sh
# _config.sh - Shared configuration for import-export-claude-global-profile skill
# Reads config from config.yml in the skill folder using pure POSIX sh
# Supports: key: value, key: "value", key: 'value', and # comments

# Get script directory (POSIX compatible - works when sourced or executed directly)
case "$0" in
    */*) SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)" ;;
    *)   SCRIPT_DIR="$(cd "$(dirname "$0")/.." && pwd)" ;;
esac
CONFIG_FILE="$SCRIPT_DIR/../config.yml"

# ---------------------------------------------------------------------------
# Parse YAML-like config in pure POSIX sh
# Handles: key: value, # comments, quoted values, blank lines
# Uses character-by-character iteration via expr to detect quoted regions
# ---------------------------------------------------------------------------
parse_yaml_config() {
    if [ ! -f "$CONFIG_FILE" ]; then
        return
    fi

    while IFS= read -r line || [ -n "$line" ]; do
        # Strip leading whitespace
        no_lead="$(echo "$line" | sed 's/^[[:space:]]*//')"

        # Skip blank lines
        [ -z "$no_lead" ] && continue

        # Skip comment-only lines (first char is #)
        case "$no_lead" in
            \#*) continue ;;
        esac

        # Remove inline comments (but not inside quoted values)
        # Use bash built-in for speed on Windows Git Bash (avoid slow expr in loop)
        in_quote=""
        line_len="${#no_lead}"
        i=0
        result=""
        while [ $i -lt "$line_len" ]; do
            ch="${no_lead:$i:1}"
            if [ -z "$in_quote" ]; then
                if [ "$ch" = '"' ] || [ "$ch" = "'" ]; then
                    in_quote="$ch"
                elif [ "$ch" = "#" ]; then
                    # Unquoted # starts a comment - truncate here
                    break
                fi
            else
                if [ "$ch" = "$in_quote" ]; then
                    in_quote=""
                fi
            fi
            result="$result$ch"
            i=$((i + 1))
        done
        line="$result"

        # Trim trailing whitespace
        line="$(echo "$line" | sed 's/[[:space:]]*$//')"
        [ -z "$line" ] && continue

        # Parse key: value - find first colon outside quotes
        # Extract key (before colon)
        key_len="$(expr match "$line" '^[a-zA-Z_][a-zA-Z0-9_]*:')"
        if [ "$key_len" -eq 0 ]; then
            continue
        fi
        key="$(expr substr "$line" 1 "$key_len")"
        key="${key%:}"  # Remove trailing colon

        # Extract value (after colon, before any trailing content)
        rest="$(expr substr "$line" "$(expr $key_len + 1)" "$(expr length "$line" - $key_len)")"
        # Strip leading space/tab from value
        value="$(echo "$rest" | sed 's/^[[:space:]]*//')"

        # Handle quoted values - extract content between matching quotes
        case "$value" in
            \"*\" | \'*\')
                first_ch="${value:0:1}"
                rest_val="${value:1}"
                rest_len="${#rest_val}"
                j=0
                found=""
                while [ $j -lt "$rest_len" ]; do
                    ch="${rest_val:$j:1}"
                    if [ "$ch" = "$first_ch" ]; then
                        found="${rest_val:0:$j}"
                        break
                    fi
                    j=$((j + 1))
                done
                value="$found"
                ;;
            *)
                # Unquoted - strip inline comment (already handled above but safety strip)
                value="$(echo "$value" | sed 's/#.*//')"
                ;;
        esac

        # Trim trailing whitespace from value
        value="$(echo "$value" | sed 's/[[:space:]]*$//')"

        # Set variables based on key
        case "$key" in
            backup_folder)
                # Expand ~ to $HOME
                case "$value" in
                    ~*) value="$(echo "$value" | sed "s|^~|$HOME|")" ;;
                esac
                BACKUP_FOLDER="$value"
                ;;
            github_repo)
                GITHUB_REPO="$value"
                ;;
            folders)
                SYNC_FOLDERS="$value"
                ;;
            plugin_files)
                SYNC_PLUGIN_FILES="$value"
                ;;
            files)
                SYNC_FILES="$value"
                ;;
        esac
    done < "$CONFIG_FILE"
}

# Defaults — match what Claude Code actually tracks
BACKUP_FOLDER="${BACKUP_FOLDER:-"$HOME/.claude-profile"}"
GITHUB_REPO="${GITHUB_REPO:-}"
SYNC_FOLDERS="${SYNC_FOLDERS:-skills agents commands hooks}"
SYNC_PLUGIN_FILES="${SYNC_PLUGIN_FILES:-installed_plugins.json known_marketplaces.json}"
SYNC_FILES="${SYNC_FILES:-settings.json AGENTS.md CLAUDE.md}"

# Parse config file
parse_yaml_config

# Export for child scripts
export BACKUP_FOLDER
export GITHUB_REPO
export SYNC_FOLDERS
export SYNC_PLUGIN_FILES
export SYNC_FILES
export CONFIG_FILE
