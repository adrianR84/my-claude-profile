---
name: export-claude-global-profile
description: Export all Claude Code global settings (skills, agents, commands, hooks, plugins) to a backup repository and push to remote. Trigger whenever the user says "export my claude profile", "backup my claude settings", "sync claude profile", "/export-claude-global-profile", or similar.
allowed-tools: Bash(bash *) Read
---

## What this skill does

Exports all global Claude Code settings from `~/.claude/` to a local git repository at `~/.claude-profile/`, commits the changes with an auto-generated timestamped message, and pushes to the configured remote. Use this whenever the user wants to back up or sync their Claude Code global configuration.

## How it works

All logic lives in a single bash script at:
```
~/.claude/skills/export-claude-global-profile/scripts/export-claude-global-profile.sh
```

This keeps the number of bash commands to a minimum (one permission prompt for the whole operation).

## Steps

1. **Confirm** — Ask the user to confirm they want to export and push their Claude profile.

2. **Run the script** — Execute:
   ```bash
   bash ~/.claude/skills/export-claude-global-profile/scripts/export-claude-global-profile.sh
   ```

3. **Report the output** — Share the script's output with the user exactly as returned.

## Folders exported

- `skills/`
- `agents/`
- `commands/`
- `hooks/`

## Files exported

- `settings.json` (if exists)
- `AGENTS.md` (if exists)
- `CLAUDE.md` (if exists)

## Plugin files exported (from `plugins/`)

- `installed_plugins.json` (if exists)
- `known_marketplaces.json` (if exists)

## What the script does

1. Creates `~/.claude-profile/` and runs `git init` if not already a repo
2. Syncs each folder using `rm -rf` + `cp -r` (removes stale files in destination)
3. Syncs individual files (`settings.json`, `AGENTS.md`, `CLAUDE.md`) if they exist
4. Syncs specific plugin files (`installed_plugins.json`, `known_marketplaces.json`) from `plugins/` if they exist
5. Skips any folder/file that doesn't exist in `~/.claude/`
6. If no changes: exits with "already up to date"
7. If changes: auto-commits with timestamped message, then pushes to remote
8. If no remote: commits but skips push with instructions to add one

## Important notes

- This is a **read-only export** — it never writes to `~/.claude/`
- The script handles its own error reporting and exit codes
- If the script fails, report the error to the user
- **After restoring settings from backup:** Run `/reload-plugins` to load plugins
