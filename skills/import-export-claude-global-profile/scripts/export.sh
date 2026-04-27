#!/usr/bin/env bash
# export.sh
# Exports Claude Code global settings to ~/.claude-profile/, and optionally pushes to GitHub.
# Usage: bash ~/.claude/skills/import-export-claude-global-profile/scripts/export.sh [merge|clean] [options]
#   merge (default): source items added/updated in destination, destination items preserved
#   clean: items not in source are removed from destination
# Options:
#   --local-only          Skip GitHub push (local backup only)
#   --exclude FILE        Exclude a file from sync (can be used multiple times)
#   --redact-with STRING  Replace sensitive values in settings.json with STRING before backup

set -e

# Load shared config (github_repo, backup_folder from config.yml)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/_config.sh"

SRC="$HOME/.claude"
DST="$BACKUP_FOLDER"
MODE="merge"
LOCAL_ONLY="false"
EXCLUDED_FILES=()
REDACT_WITH=""

# Parse arguments
while [[ $# -gt 0 ]]; do
  case "$1" in
    merge|clean)
      MODE="$1"
      shift
      ;;
    --local-only)
      LOCAL_ONLY="true"
      shift
      ;;
    --exclude)
      EXCLUDED_FILES+=("$2")
      shift 2
      ;;
    --redact-with)
      REDACT_WITH="$2"
      shift 2
      ;;
    *)
      echo "Unknown option: $1"
      echo "Usage: $0 [merge|clean] [--local-only] [--exclude FILE] [--redact-with STRING]"
      exit 1
      ;;
  esac
done

# Use config values (sourced from config.yml via _config.sh)
FOLDERS="$SYNC_FOLDERS"
PLUGIN_FILES="$SYNC_PLUGIN_FILES"
FILES="$SYNC_FILES"

# Remove excluded files from FILES list
if [[ ${#EXCLUDED_FILES[@]} -gt 0 ]]; then
  FILTERED_FILES=()
  for f in $FILES; do
    skip=false
    for ex in "${EXCLUDED_FILES[@]}"; do
      if [[ "$f" == "$ex" ]]; then
        skip=true
        echo "  Excluded: $f"
        break
      fi
    done
    [[ "$skip" == "false" ]] && FILTERED_FILES+=("$f")
  done
  FILES="${FILTERED_FILES[*]}"
fi

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

  # Handle settings.json with redaction
  if [[ "$file" == "settings.json" ]] && [[ -n "$REDACT_WITH" ]]; then
    if [ -f "$src_file" ]; then
      # Create a temporary copy, redact it, then copy to destination
      TEMP_COPY=$(mktemp)
      cp "$src_file" "$TEMP_COPY"
      node "$SCRIPT_DIR/scan-sensitive.js" redact "$TEMP_COPY" --with "$REDACT_WITH"
      cp "$TEMP_COPY" "$dst_file"
      rm "$TEMP_COPY"
      echo "  Synced: $file (redacted with \"$REDACT_WITH\")"
    fi
  else
    if [ -f "$src_file" ]; then
      cp "$src_file" "$dst_file"
      echo "  Synced: $file"
    elif [ "$MODE" = "clean" ]; then
      if [ -f "$dst_file" ]; then
        rm "$dst_file"
        echo "  Removed: $file (not in source)"
      fi
    fi
  fi
done

# Handle excluded files in clean mode (remove from destination)
if [[ "$MODE" == "clean" ]] && [[ ${#EXCLUDED_FILES[@]} -gt 0 ]]; then
  for file in "${EXCLUDED_FILES[@]}"; do
    dst_file="$DST/$file"
    if [ -f "$dst_file" ]; then
      rm "$dst_file"
      echo "  Removed: $file (excluded)"
    fi
  done
fi

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
# 6. GitHub push (only if repo is configured and not --local-only)
# ---------------------------------------------------------------------------
if [[ "$LOCAL_ONLY" == "true" ]]; then
  echo ""
  echo "Local-only export — GitHub push skipped."
  echo "Synced to: $DST"
  exit 0
fi

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
if git push -u origin "$BRANCH" 2>/dev/null; then
  echo ""
  echo "Done. Synced to: $DST"
  echo "Pushed to: $GITHUB_REPO"
  echo "Commit: $COMMIT_SHA"
else
  echo ""
  echo "Push failed. Commit exists locally at: $DST"
  echo "Manual push needed: cd \"$DST\" && git push -u origin \"$BRANCH\""
fi
