#!/usr/bin/env bash
# export.sh
# Exports Claude Code global settings to ~/.claude-profile/, and optionally pushes to GitHub.
# Usage: bash ~/.claude/skills/import-export-claude-global-profile/scripts/export.sh [merge|clean]
#   merge (default): source items added/updated in destination, destination items preserved
#   clean: items not in source are removed from destination

set -e

# Load shared config (github_repo, backup_folder from config.yml)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/_config.sh"

SRC="$HOME/.claude"
DST="$BACKUP_FOLDER"
MODE="${1:-merge}"

# Use config values (sourced from config.yml via _config.sh)
FOLDERS="$SYNC_FOLDERS"
PLUGIN_FILES="$SYNC_PLUGIN_FILES"
FILES="$SYNC_FILES"

# ---------------------------------------------------------------------------
# 1. Create destination folder if needed
# ---------------------------------------------------------------------------
if [ ! -d "$DST" ]; then
  mkdir -p "$DST"
fi

# ---------------------------------------------------------------------------
# 2. Sync folders
# ---------------------------------------------------------------------------
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
      echo "  Removed: $folder/ (not in source)"
    fi
  fi
  # Merge mode: do nothing if source doesn't exist (preserve destination)
done

# ---------------------------------------------------------------------------
# 3. Sync individual files
# ---------------------------------------------------------------------------
echo "Syncing files ($MODE mode)..."
for file in $FILES; do
  src_file="$SRC/$file"
  dst_file="$DST/$file"

  if [ -f "$src_file" ]; then
    cp "$src_file" "$dst_file"
    echo "  Synced: $file"
  elif [ "$MODE" = "clean" ]; then
    # Clean sync: remove if not in source
    if [ -f "$dst_file" ]; then
      rm "$dst_file"
      echo "  Removed: $file (not in source)"
    fi
  fi
  # Merge mode: do nothing if source doesn't exist (preserve destination)
done

# ---------------------------------------------------------------------------
# 4. Sync plugin files
# ---------------------------------------------------------------------------
echo "Syncing plugin files ($MODE mode)..."
if [ -d "$SRC/plugins" ]; then
  mkdir -p "$DST/plugins"
  for file in $PLUGIN_FILES; do
    src_file="$SRC/plugins/$file"
    dst_file="$DST/plugins/$file"

    if [ -f "$src_file" ]; then
      cp "$src_file" "$dst_file"
      echo "  Synced: plugins/$file"
    elif [ "$MODE" = "clean" ]; then
      if [ -f "$dst_file" ]; then
        rm "$dst_file"
        echo "  Removed: plugins/$file (not in source)"
      fi
    fi
  done
elif [ "$MODE" = "clean" ]; then
  # Clean sync: remove plugins folder if not in source
  if [ -d "$DST/plugins" ]; then
    rm -rf "$DST/plugins"
    echo "  Removed: plugins/ (not in source)"
  fi
fi

# ---------------------------------------------------------------------------
# 5. Sanitize plugin JSON files (convert absolute → relative paths)
# ---------------------------------------------------------------------------
echo "Sanitizing plugin files (export mode)..."
SANITIZE_SCRIPT="$SCRIPT_DIR/sanitize-json.js"
CLAUDE_CONFIG_DIR_VALUE="${CLAUDE_CONFIG_DIR:-$HOME/.claude}"
for file in $PLUGIN_FILES; do
  dst_file="$DST/plugins/$file"
  if [ -f "$dst_file" ]; then
    node "$SANITIZE_SCRIPT" export "$dst_file" --config-dir "$CLAUDE_CONFIG_DIR_VALUE"
  fi
done

# ---------------------------------------------------------------------------
# 6. GitHub push (only if repo is configured)
# ---------------------------------------------------------------------------
if [ -z "$GITHUB_REPO" ]; then
  echo ""
  echo "No GitHub repo configured — local export complete."
  echo "Synced to: $DST"
  echo "To enable GitHub backup, add your repo URL to:"
  echo "  ~/.claude/skills/import-export-claude-global-profile/config.yml"
  exit 0
fi

# GitHub is configured — initialize/push to remote
cd "$DST"

# Initialize git if needed
if [ ! -d ".git" ]; then
  git init
  echo "Created git repo at $DST"
  git remote add origin "$GITHUB_REPO"
  echo "Added remote: $GITHUB_REPO"
fi

# Ensure remote is set correctly
ORIGIN_URL=$(git remote get-url origin 2>/dev/null)
if [ -z "$ORIGIN_URL" ]; then
  git remote add origin "$GITHUB_REPO"
  echo "Added remote: $GITHUB_REPO"
elif [ "$ORIGIN_URL" != "$GITHUB_REPO" ]; then
  git remote set-url origin "$GITHUB_REPO"
  echo "Updated remote to: $GITHUB_REPO"
fi

# Check for changes
if [ -z "$(git status --porcelain)" ]; then
  echo ""
  echo "No changes to commit — profile is already up to date."
  exit 0
fi

# Commit and push
git add -A
git commit -m "Export Claude profile - $(date '+%Y-%m-%d %H:%M')"
COMMIT_SHA=$(git rev-parse --short HEAD)
echo "Committed: $COMMIT_SHA"

BRANCH=$(git rev-parse --abbrev-ref HEAD)
echo "Pushing to $GITHUB_REPO..."
git push -u origin "$BRANCH" --force 2>/dev/null || git push -u origin "$BRANCH"

echo ""
echo "Done. Synced to: $DST"
echo "Pushed to: $GITHUB_REPO"
echo "Commit: $COMMIT_SHA"
