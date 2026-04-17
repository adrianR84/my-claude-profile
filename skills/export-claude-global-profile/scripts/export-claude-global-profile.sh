#!/usr/bin/env bash
# export-claude-global-profile.sh
# Exports Claude Code global settings to ~/.claude-profile/, commits, and pushes.
# Usage: bash ~/.claude/skills/export-claude-global-profile/scripts/export-claude-global-profile.sh

set -e

SRC="$HOME/.claude"
DST="$HOME/.claude-profile"

# Folders to export (space-separated)
FOLDERS="skills agents commands hooks"

# Plugin files to export (space-separated, if they exist in plugins/)
PLUGIN_FILES="installed_plugins.json known_marketplaces.json"

# Individual files to export (space-separated, if they exist)
FILES="settings.json AGENTS.md CLAUDE.md"

# ---------------------------------------------------------------------------
# 1. Create destination repo if needed
# ---------------------------------------------------------------------------
if [ ! -d "$DST" ]; then
  mkdir -p "$DST"
fi

cd "$DST"
if [ ! -d ".git" ]; then
  git init
  echo "Created git repo at $DST"
fi

# ---------------------------------------------------------------------------
# 2. Sync folders
# ---------------------------------------------------------------------------
for folder in $FOLDERS; do
  src_path="$SRC/$folder"
  dst_path="$DST/$folder"

  if [ -d "$src_path" ]; then
    rm -rf "$dst_path"
    cp -r "$src_path" "$dst_path"
    echo "Synced: $folder/"
  else
    # Remove stale copy if source no longer exists
    if [ -d "$dst_path" ]; then
      rm -rf "$dst_path"
      echo "Removed stale: $folder/ (source deleted)"
    fi
  fi
done

# ---------------------------------------------------------------------------
# 3. Sync individual files
# ---------------------------------------------------------------------------
for file in $FILES; do
  src_file="$SRC/$file"
  dst_file="$DST/$file"

  if [ -f "$src_file" ]; then
    cp "$src_file" "$dst_file"
    echo "Synced: $file"
  else
    # Remove stale copy if source no longer exists
    if [ -f "$dst_file" ]; then
      rm "$dst_file"
      echo "Removed stale: $file (source deleted)"
    fi
  fi
done

# ---------------------------------------------------------------------------
# 4. Sync plugin files
# ---------------------------------------------------------------------------
if [ -d "$SRC/plugins" ]; then
  mkdir -p "$DST/plugins"
  for file in $PLUGIN_FILES; do
    src_file="$SRC/plugins/$file"
    dst_file="$DST/plugins/$file"

    if [ -f "$src_file" ]; then
      cp "$src_file" "$dst_file"
      echo "Synced: plugins/$file"
    else
      # Remove stale copy if source no longer exists
      if [ -f "$dst_file" ]; then
        rm "$dst_file"
        echo "Removed stale: plugins/$file (source deleted)"
      fi
    fi
  done
fi

# ---------------------------------------------------------------------------
# 5. Check for changes
# ---------------------------------------------------------------------------
if [ -z "$(git status --porcelain)" ]; then
  echo ""
  echo "No changes to commit — your Claude profile is already up to date."
  exit 0
fi

# ---------------------------------------------------------------------------
# 6. Commit
# ---------------------------------------------------------------------------
git add -A
git commit -m "Export Claude profile - $(date '+%Y-%m-%d %H:%M')"
COMMIT_SHA=$(git rev-parse --short HEAD)
echo "Committed: $COMMIT_SHA"

# ---------------------------------------------------------------------------
# 7. Push
# ---------------------------------------------------------------------------
if [ -z "$(git remote -v)" ]; then
  echo "No remote configured — commit succeeded but push was skipped."
  echo "Add a remote with: git remote add origin <url>"
  exit 0
fi

BRANCH=$(git rev-parse --abbrev-ref HEAD)
git push -u origin "$BRANCH"
echo "Pushed to remote."

# ---------------------------------------------------------------------------
# 8. Summary
# ---------------------------------------------------------------------------
echo ""
echo "Done. Synced folders: $FOLDERS"
echo "Synced files: $FILES"
echo "Synced plugin files: plugins/$PLUGIN_FILES"
echo "Commit: $COMMIT_SHA"
echo ""
echo "IMPORTANT: After restoring settings, run /reload-plugins to load plugins."
