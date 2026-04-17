#!/usr/bin/env bash
# import-claude-global-profile.sh
# Restores Claude Code global settings from ~/.claude-profile/, backing up existing files first.
# Usage: bash ~/.claude/skills/import-claude-global-profile/scripts/import-claude-global-profile.sh

set -e

SRC="$HOME/.claude-profile"
DST="$HOME/.claude"

# Folders to sync (merge into destination, preserving existing subfolders)
FOLDERS="skills agents commands hooks"

# Plugin files to restore (from plugins/)
PLUGIN_FILES="installed_plugins.json known_marketplaces.json"

# Individual files to backup and restore
FILES="settings.json AGENTS.md CLAUDE.md"

# ---------------------------------------------------------------------------
# 1. Check if backup repo exists
# ---------------------------------------------------------------------------
if [ ! -d "$SRC" ]; then
  echo "ERROR: ~/.claude-profile/ does not exist."
  echo "Run /export-claude-global-profile first to create a backup."
  exit 1
fi

cd "$SRC"

# Check if it's a git repo
if [ ! -d ".git" ]; then
  echo "ERROR: ~/.claude-profile/ is not a git repository."
  echo "Run /export-claude-global-profile first to initialize the backup repo."
  exit 1
fi

# ---------------------------------------------------------------------------
# 2. Pull latest changes from remote
# ---------------------------------------------------------------------------
if [ -n "$(git remote -v)" ]; then
  echo "Pulling latest changes from remote..."
  git pull origin "$(git rev-parse --abbrev-ref HEAD)" 2>/dev/null || git pull 2>/dev/null || true
else
  echo "No remote configured — using local backup only."
fi

# ---------------------------------------------------------------------------
# 3. Backup existing files in ~/.claude/ (only files, not folders)
# ---------------------------------------------------------------------------
echo ""
echo "Backing up existing files..."

for file in $FILES; do
  dst_file="$DST/$file"

  if [ -f "$dst_file" ]; then
    cp "$dst_file" "${dst_file}.backup"
    echo "  Backed up: $file -> $file.backup"
  fi
done

# Backup plugin files
for file in $PLUGIN_FILES; do
  dst_file="$DST/plugins/$file"

  if [ -f "$dst_file" ]; then
    mkdir -p "$DST/plugins"
    cp "$dst_file" "${dst_file}.backup"
    echo "  Backed up: plugins/$file -> plugins/$file.backup"
  fi
done

# ---------------------------------------------------------------------------
# 4. Sync folders (merge into destination, preserving existing subfolders)
# ---------------------------------------------------------------------------
echo ""
echo "Restoring folders..."

for folder in $FOLDERS; do
  src_path="$SRC/$folder"
  dst_path="$DST/$folder"

  if [ -d "$src_path" ]; then
    # Create destination if it doesn't exist
    if [ ! -d "$dst_path" ]; then
      mkdir -p "$dst_path"
    fi
    # Merge: copy contents from source into destination (preserves existing subfolders in dst)
    cp -r "$src_path"/* "$dst_path/" 2>/dev/null || true
    echo "  Synced: $folder/"
  fi
  # If source doesn't exist, do nothing (preserve destination as-is)
done

# ---------------------------------------------------------------------------
# 5. Restore individual files (only if exists in source)
# ---------------------------------------------------------------------------
echo ""
echo "Restoring files..."

for file in $FILES; do
  src_file="$SRC/$file"
  dst_file="$DST/$file"

  if [ -f "$src_file" ]; then
    cp "$src_file" "$dst_file"
    echo "  Restored: $file"
  fi
  # If source doesn't exist, do nothing (preserve destination as-is)
done

# Restore plugin files
for file in $PLUGIN_FILES; do
  src_file="$SRC/plugins/$file"
  dst_file="$DST/plugins/$file"

  if [ -f "$src_file" ]; then
    mkdir -p "$DST/plugins"
    cp "$src_file" "$dst_file"
    echo "  Restored: plugins/$file"
  fi
  # If source doesn't exist, do nothing (preserve destination as-is)
done

# ---------------------------------------------------------------------------
# 6. Summary
# ---------------------------------------------------------------------------
echo ""
echo "Done. Synced folders (merge): $FOLDERS"
echo "Restored files: $FILES"
echo "Restored plugin files: plugins/$PLUGIN_FILES"
echo ""
echo "IMPORTANT: Run /reload-plugins to load restored plugins."
