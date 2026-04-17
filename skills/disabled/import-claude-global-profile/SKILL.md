---
name: import-claude-global-profile
description: Restore Claude Code global settings from a backup repository at ~/.claude-profile/. Backs up existing files with ".backup" suffix before overwriting. Trigger whenever the user says "restore my claude profile", "import claude settings", "restore from backup", "reset claude settings", "/import-claude-global-profile", or similar.
allowed-tools: Bash(bash *) Read
---

## What this skill does

Restores Claude Code global settings from `~/.claude-profile/` to `~/.claude/`. Existing files are backed up with a `.backup` suffix before being overwritten. Use this whenever the user wants to restore their Claude Code configuration from a previous backup.

## How it works

All logic lives in a single bash script at:
```
~/.claude/skills/import-claude-global-profile/scripts/import-claude-global-profile.sh
```

This keeps the number of bash commands to a minimum (one permission prompt for the whole operation).

## Steps

1. **Confirm** — Ask the user to confirm they want to restore from backup (this will overwrite existing files).

2. **Run the script** — Execute:
   ```bash
   bash ~/.claude/skills/import-claude-global-profile/scripts/import-claude-global-profile.sh
   ```

3. **Report the output** — Share the script's output with the user exactly as returned.

## Folders restored

- `skills/`
- `agents/`
- `commands/`
- `hooks/`

## Files backed up and restored

- `settings.json`
- `AGENTS.md`
- `CLAUDE.md`

## Plugin files backed up and restored (from `plugins/`)

- `installed_plugins.json`
- `known_marketplaces.json`

## What the script does

1. Checks that `~/.claude-profile/` exists and is a git repo
2. Pulls latest changes from remote (if configured)
3. Backs up existing files in `~/.claude/` with `.backup` suffix (files only, not folders)
4. Syncs folders from backup (merge — preserves existing subfolders in destination)
5. Restores individual files from backup (only if they exist in source)
6. Warns to run `/reload-plugins` after restore

## Important notes

- **Files are backed up before overwrite** — backed up with `.backup` suffix
- **Folders are merged** — source subfolders are added/updated into destination; existing destination subfolders are preserved
- **Destination items not in source are preserved** — folders and files only exist in destination are kept as-is
- If `~/.claude-profile/` doesn't exist, the script exits with an error
- **After restoring:** Run `/reload-plugins` to load restored plugins
