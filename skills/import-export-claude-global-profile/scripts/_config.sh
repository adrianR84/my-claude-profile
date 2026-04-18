#!/usr/bin/env bash
# _config.sh - Shared configuration for import-export-claude-global-profile skill
# Reads config from config.yml in the skill folder using pure bash
# Supports: key: value, key: "value", key: 'value', and # comments

SKILL_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CONFIG_FILE="$SKILL_DIR/config.yml"

# ---------------------------------------------------------------------------
# Parse YAML-like config in pure bash
# Handles: key: value, # comments, quoted values, blank lines
# ---------------------------------------------------------------------------
parse_yaml_config() {
  local line key value in_comment

  if [ ! -f "$CONFIG_FILE" ]; then
    return
  fi

  while IFS= read -r line || [ -n "$line" ]; do
    # Strip leading whitespace
    line="${line#"${line%%[![:space:]]*}"}"

    # Skip blank lines and comment-only lines
    [ -z "$line" ] && continue
    [[ "$line" =~ ^#.*$ ]] && continue

    # Remove inline comments (but not inside quoted values)
    in_comment=0
    for ((i=0; i<${#line}; i++)); do
      local ch="${line:i:1}"
      if [[ "$ch" == "'" ]] || [[ "$ch" == '"' ]]; then
        in_comment=$((1 - in_comment))
      elif [[ "$ch" == "#" ]] && ((in_comment == 0)); then
        line="${line:0:i}"
        break
      fi
    done

    # Trim trailing whitespace after comment strip
    line="${line%"${line##*[![:space:]]}"}"
    [ -z "$line" ] && continue

    # Parse key: value
    if [[ "$line" =~ ^([a-zA-Z_][a-zA-Z0-9_]*)[[:space:]]*:[[:space:]]*(.*)$ ]]; then
      key="${BASH_REMATCH[1]}"
      value="${BASH_REMATCH[2]}"

      # Strip quotes from value
      value="${value#\"}"
      value="${value%\"}"
      value="${value#\'}"
      value="${value%\'}"

      # Trim trailing whitespace
      value="${value%"${value##*[![:space:]]}"}"

      case "$key" in
        backup_folder)
          BACKUP_FOLDER="${value/\~/$HOME}"
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
    fi
  done < "$CONFIG_FILE"
}

# Defaults — match what Claude Code actually tracks
BACKUP_FOLDER="${BACKUP_FOLDER:-$HOME/.claude-profile}"
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
