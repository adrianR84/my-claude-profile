#!/usr/bin/env bash
# import.sh
# Restores Claude Code global settings from the backup folder, backing up existing files first.
# If a GitHub repo is configured, pulls latest from remote first.
# Usage: bash ~/.claude/skills/import-export-claude-global-profile/scripts/import.sh [merge|clean]
#   merge (default): source items added/updated in destination, destination items preserved
#   clean: items not in source are removed from destination

set -e

# Load shared config (github_repo, backup_folder from config.yml)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/_config.sh"

SRC="$BACKUP_FOLDER"
DST="$HOME/.claude"
MODE="${1:-merge}"

# Use config values (sourced from config.yml via _config.sh)
FOLDERS="$SYNC_FOLDERS"
PLUGIN_FILES="$SYNC_PLUGIN_FILES"
FILES="$SYNC_FILES"

# ---------------------------------------------------------------------------
# 1. Pull from GitHub if repo is configured and repo has a .git folder
# ---------------------------------------------------------------------------
if [ -n "$GITHUB_REPO" ] && [ -d "$SRC/.git" ]; then
  echo "Pulling latest from GitHub..."
  cd "$SRC"
  git pull origin "$(git rev-parse --abbrev-ref HEAD)" 2>/dev/null || git pull 2>/dev/null || true
elif [ -z "$GITHUB_REPO" ] && [ ! -d "$SRC" ]; then
  echo "ERROR: No backup folder found at $SRC"
  echo "Run export first to create a local backup, or configure a GitHub repo in:"
  echo "  ~/.claude/skills/import-export-claude-global-profile/config.yml"
  exit 1
elif [ -n "$GITHUB_REPO" ] && [ ! -d "$SRC/.git" ]; then
  # Repo is configured but local is not a git repo — clone it
  echo "Cloning $GITHUB_REPO to $SRC..."
  rm -rf "$SRC"
  git clone "$GITHUB_REPO" "$SRC"
fi

# ---------------------------------------------------------------------------
# 2. Sync folders
# ---------------------------------------------------------------------------
echo ""
echo "Syncing folders ($MODE mode)..."

for folder in $FOLDERS; do
  src_path="$SRC/$folder"
  dst_path="$DST/$folder"

  if [ -d "$src_path" ]; then
    if [ "$MODE" = "clean" ]; then
      # Clean sync: remove destination first, then copy
      rm -rf "$dst_path"
      cp -r "$src_path" "$dst_path"
    else
      # Merge sync: copy contents into destination (preserves existing subfolders)
      if [ ! -d "$dst_path" ]; then
        mkdir -p "$dst_path"
      fi
      cp -r "$src_path"/* "$dst_path/" 2>/dev/null || true
    fi
    echo "  Synced: $folder/"
  elif [ "$MODE" = "clean" ]; then
    # Clean sync: remove if not in source
    if [ -d "$dst_path" ]; then
      rm -rf "$dst_path"
      echo "  Removed: $folder/ (not in backup)"
    fi
  fi
  # Merge mode: do nothing if source doesn't exist (preserve destination)
done

# ---------------------------------------------------------------------------
# 3. Restore individual files
# ---------------------------------------------------------------------------
echo ""
echo "Restoring files ($MODE mode)..."

for file in $FILES; do
  src_file="$SRC/$file"
  dst_file="$DST/$file"

  if [ -f "$src_file" ]; then
    cp "$src_file" "$dst_file"
    echo "  Restored: $file"
  elif [ "$MODE" = "clean" ]; then
    if [ -f "$dst_file" ]; then
      rm "$dst_file"
      echo "  Removed: $file (not in backup)"
    fi
  fi
  # Merge mode: do nothing if source doesn't exist (preserve destination)
done

# Restore plugin files
for file in $PLUGIN_FILES; do
  src_file="$SRC/plugins/$file"
  dst_file="$DST/plugins/$file"

  if [ -f "$src_file" ]; then
    mkdir -p "$DST/plugins"
    cp "$src_file" "$dst_file"
    echo "  Restored: plugins/$file"
  elif [ "$MODE" = "clean" ]; then
    if [ -f "$dst_file" ]; then
      rm "$dst_file"
      echo "  Removed: plugins/$file (not in backup)"
    fi
  fi
  # Merge mode: do nothing if source doesn't exist (preserve destination)
done

# ---------------------------------------------------------------------------
# 4. Sanitize plugin JSON files (convert relative → absolute paths)
# ---------------------------------------------------------------------------
echo "Sanitizing plugin files (import mode)..."
SANITIZE_SCRIPT="$SCRIPT_DIR/sanitize-json.js"
CLAUDE_CONFIG_DIR_VALUE="${CLAUDE_CONFIG_DIR:-$HOME/.claude}"
for file in $PLUGIN_FILES; do
  dst_file="$DST/plugins/$file"
  if [ -f "$dst_file" ]; then
    node "$SANITIZE_SCRIPT" import "$dst_file" --config-dir "$CLAUDE_CONFIG_DIR_VALUE"
  fi
done

# ---------------------------------------------------------------------------
# 5. Summary
# ---------------------------------------------------------------------------
echo ""
echo "Done. Sync mode: $MODE"
echo "Synced folders: $FOLDERS"
echo "Restored files: $FILES"
echo "Restored plugin files: plugins/$PLUGIN_FILES"
echo ""
echo "IMPORTANT: Run /reload-plugins to load restored plugins."
