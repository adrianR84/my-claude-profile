---
name: import-export-claude-global-profile
description: Export, import, or diff Claude Code global settings. Trigger whenever the user says "sync claude profile", "compare claude settings", "diff claude backup", "backup claude", "restore claude from backup", "check claude differences", "export claude profile", "import claude profile", or similar.
allowed-tools: Bash(bash *) Read Write
---

## What this skill does

Exports, imports, or compares Claude Code global settings with a **local backup folder**. A GitHub remote is **optional** — if configured, the skill will also push to/pull from GitHub; if not, it works fully offline.

## Configuration

Config is stored in `~/.claude/skills/import-export-claude-global-profile/config.yml` in YAML format. Edit this file to change settings.

### Supported keys

| Key | Default | Description |
|-----|---------|-------------|
| `github_repo` | _(none)_ | GitHub repository URL for remote sync. If empty, works fully local. |
| `backup_folder` | `~/.claude-profile` | Local backup folder path. |
| `folders` | `skills agents commands hooks` | Space-separated list of folders to sync. |
| `plugin_files` | `installed_plugins.json known_marketplaces.json` | Space-separated list of plugin files to sync. |
| `files` | `settings.json AGENTS.md CLAUDE.md` | Space-separated list of individual files to sync. |

### Example config

```yaml
# Backup folder (default: ~/.claude-profile)
backup_folder: ~/.claude-profile

# GitHub remote — leave empty to disable remote sync (local-only mode)
github_repo: https://github.com/yourusername/your-repo-name

# What to sync (all space-separated lists)
folders: skills agents commands hooks
plugin_files: installed_plugins.json known_marketplaces.json
files: settings.json AGENTS.md CLAUDE.md
```

## On first load

**Always tell the user this at the start of the conversation:**

> This skill is configurable. All settings — backup folder, GitHub repo, and what to sync — are in `~/.claude/skills/import-export-claude-global-profile/config.yml`. You can customize any of them. Would you like to review or change any settings before we proceed?

## Operation selection

**If the user clearly states what they want, proceed directly:**
- User says "export", "push", "backup" → run export
- User says "import", "restore", "restore from backup" → run import
- User says "diff", "compare", "check differences" → run diff

**If the intent is unclear, ALWAYS ask first:**
Present all three options:
- **Diff (preview)** — See what's different between ~/.claude/ and backup folder
- **Export** — Save local settings to backup folder
- **Import** — Restore settings from backup folder to ~/.claude/

**Want to change what gets synced or where?** Edit `~/.claude/skills/import-export-claude-global-profile/config.yml`.

## Scripts

- **Diff:** `~/.claude/skills/import-export-claude-global-profile/scripts/diff.sh`
- **Export:** `~/.claude/skills/import-export-claude-global-profile/scripts/export.sh`
- **Import:** `~/.claude/skills/import-export-claude-global-profile/scripts/import.sh`

Config: `~/.claude/skills/import-export-claude-global-profile/config.yml`

---

## Diff (Preview)

### When to use
Before running export or import, user wants to see what differences exist between `~/.claude/` and the backup folder.

### Steps
1. **Run:** `bash ~/.claude/skills/import-export-claude-global-profile/scripts/diff.sh`
2. **Report** — Show the output verbatim in a code block, then summarize what it means.

### What it uses from config
`backup_folder`, `folders`, `files`, and `plugin_files` from `config.yml`.

---

## Export

### When to use
User wants to back up their Claude Code settings.

### Steps
1. **Run diff first** — Execute `diff.sh` and show the output to the user. This shows what would change.
2. **Choose sync mode** — Ask the user to choose:
   - **Merge sync (default):** Source items added/updated in backup. Items only in backup are preserved. Safer.
   - **Clean sync:** Backup made to exactly match source. Removes items not in source.
3. **Run:** `bash ~/.claude/skills/import-export-claude-global-profile/scripts/export.sh [merge|clean]`
4. **Report** — Share the output.

### What gets exported
Defined by `folders`, `files`, and `plugin_files` in `config.yml`. Defaults:
- **Folders:** `skills/`, `agents/`, `commands/`, `hooks/`
- **Files:** `settings.json`, `AGENTS.md`, `CLAUDE.md`
- **Plugin files:** `plugins/installed_plugins.json`, `plugins/known_marketplaces.json`

### GitHub
If `github_repo` is set in config, export also commits and pushes to GitHub. If not, it's local-only.

---

## Import

### When to use
User wants to restore their Claude Code settings from the backup folder.

### Steps
1. **Run diff first** — Execute `diff.sh` and show the output to the user. This shows what would change.
2. **Choose sync mode** — Ask the user to choose:
   - **Merge sync (default):** Backup items added/updated in ~/.claude/. Items only in ~/.claude/ are preserved.
   - **Clean sync:** ~/.claude/ made to exactly match backup. Removes items not in backup.
3. **Run:** `bash ~/.claude/skills/import-export-claude-global-profile/scripts/import.sh [merge|clean]`
4. **Report** — Share the output.

### What gets imported
Defined by `folders`, `files`, and `plugin_files` in `config.yml`. Defaults match export above.

### GitHub
If `github_repo` is set in config, import also pulls from GitHub first. If not, it's local-only.

---

## Sync modes explained

| Mode | Behavior |
|------|----------|
| **merge (default)** | Source items added/updated in destination. Destination-only items preserved. No data loss. |
| **clean** | Destination made to match source exactly. Items not in source are deleted. Use with caution. |

---

## Important notes

- Files are backed up with `.backup` suffix before import overwrite
- Config file: `~/.claude/skills/import-export-claude-global-profile/config.yml`
- After import: run `/reload-plugins` to load restored plugins
- **Merge is recommended** — clean sync can delete items you may want to keep
- **Diff is always run first** before export or import — this shows differences and helps the user make an informed decision
