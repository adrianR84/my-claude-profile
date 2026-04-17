---
name: permissions-command
description: Allow specific tool permissions locally in the current project for running a user-requested command without confirmation. Use when user asks to "add permissions for X", "allow running Y", "set up permissions for this project so I don't have to approve Z", or any variation — the user is essentially saying "I trust this command, just let it run." This skill does the work itself; it does not ask the user to add permissions manually.
---

## How to identify needed permissions

### Step 0 — Detect MCP servers and tools

Scan `$ARGUMENTS` for mentions of MCP (Model Context Protocol) servers and tools. For MCP servers, use the wildcard suffix `__*` to grant access to **all tools** from that server at once. The format is `mcp__<server-id>__*`. Exam00:07 28/03/2026ples:

- **"use Chrome DevTools" / "browser automation" / "take a screenshot"** → `mcp__plugin_chrome-devtools-mcp_chrome-devtools__*`
- **"fetch docs" / "look up documentation" / "context7"** → `mcp__plugin_context7_context7__*`
- **"run a filesystem operation" / "read/write files outside the project"** → `mcp__plugin_filesystem__*`
- **"access Google Sheets" / "sheets API"** → `mcp__plugin_google-sheets__*`
- **"Slack message" / "send to Slack"** → `mcp__plugin_slack__*`
- **"GitHub PR" / "create a GitHub issue"** → `mcp__plugin_github__*`
- **Any other MCP server or tool mentioned** → use `mcp__<server-id>__*` for the whole server

Also check the skill's SKILL.md for an `mcpServers` or `compatibility` field listing MCP dependencies — use the `__*` wildcard for each server.

### Step 1 — Is the request a skill invocation?

Parse $ARGUMENTS:

- If it starts with `/` (e.g., `/code-review`, `/skill-creator`), the skill name is the word after the slash.
- If it mentions a skill by name (e.g., "allow permissions for code-review", "set up the feature-dev skill"), extract the skill identifier.
- The skills directory is at `C:/Users/adria/.claude/skills/`. Skill SKILL.md files are at `<skills-dir>/<skill-name>/SKILL.md`.
- If the skill is installed elsewhere or a path is given, use that path directly.

### Step 2 — If a skill is found, read its SKILL.md

1. **Read the skill's SKILL.md** at `<skills-dir>/<skill-name>/SKILL.md`.
2. **Extract permissions from the `compatibility` field** — if it lists required tools, use those.
3. **Infer from the description and body** — look for mentions of which tools the skill uses (e.g., "uses Bash to run tests", "spawns subagents via Agent"). Use the fine-grained Bash patterns from Step 3 where possible.
4. **Check for nested skill invocations** — scan the skill's description and body for mentions of other skills (paths like `/skill-name`, skill directory names like `find-bugs`, or explicit "uses the X skill" references). For each referenced skill, recursively apply steps 1–4 to collect its permissions too. Keep a set of already-visited skills to avoid infinite loops (e.g., A → B → A).
5. **Union with the manual inference guide below** — a skill typically needs `Read` and `Glob` as baseline, plus any tools it explicitly uses.

### Step 3 — Fallback: manual inference (fine-grained Bash)

**Never grant blanket `Bash` permission.** Always narrow Bash to the specific command family the request needs. Use the format `Bash(<command-pattern>)` where `<command-pattern>` is a glob matching the allowed command name(s). Common mappings:

- **"npm install" / "install dependencies" / "npm ci"** → `Bash(npm *)`
- **"run npm script" / "npm run" / "npm test" / "npm start"** → `Bash(npm *)`
- **"pip install" / "pip install X"** → `Bash(pip *)`
- **"build" / "compile" / "run build"** → `Bash(npm *)` or `Bash(./node_modules/.bin/*)` or `Bash(./gradlew *)`
- **"run tests" / "jest" / "pytest" / "run the tests"** → `Bash(jest *)` / `Bash(python *)` / `Bash(npm test)` — match the specific test runner
- **"git commit" / "git push" / "git pull"** → `Bash(git *)`
- **"git checkout" / "git branch"** → `Bash(git *)`
- **"node script" / "run a node command"** → `Bash(node *)`
- **"python script" / "run python" / "pip"** → `Bash(python *)`
- **"curl" / "fetch from URL" / "download"** → `Bash(curl *)` or `Bash(wget *)`
- **"install a package globally" / "npm install -g"** → `Bash(npm *)`
- **"run make" / "make build"** → `Bash(make *)`
- **"docker build" / "docker run"** → `Bash(docker *)`
- **"kubectl" / "helm"** → `Bash(kubectl *)` / `Bash(helm *)`

**When Bash is uncertain:** If the request could involve arbitrary shell commands (e.g., "run arbitrary scripts", "execute a file", "run this bash script"), do NOT grant Bash. Instead grant only the specific safe tools needed (Read, Write, Edit, Glob) and tell the user that Bash cannot be safely auto-permissioned for this request — they should grant it manually or be more specific.

**Combining patterns:** If a skill needs multiple command families, grant multiple patterns: `Bash(npm *)` + `Bash(git *)`.

Other tool permissions (non-Bash):
- **"create a file" / "write X to disk" / "save this"** → `Write`
- **"read this file" / "show me the contents"** → `Read`
- **"search for X in files" / "grep" / "find where X is defined"** → `Grep`
- **"find all files matching X" / "glob" / "list X files"** → `Glob`
- **"fetch from URL" / "download" (without curl)** → `WebFetch`
- **"search the web" / "google" / "look up"** → `WebSearch`
- **"run a subagent" / "spawn an agent" / "delegate to another Claude"** → `Agent`
- **"schedule a cron job" / "remind me to"** → `CronCreate`
- **"create tasks" / "add todos" / "track this"** → `TaskCreate`

Include `Read` and `Glob` as safety deps since most tasks need them to inspect the project.

## Steps

1. **Read** `.claude/settings.json` in the current project directory. If it doesn't exist, note that you'll create it.
2. **Determine** the minimum set of permissions needed from the request, using fine-grained Bash patterns — never blanket `Bash`.
3. **Check** which permissions are already present in `settings.json` before making any changes.
4. **Merge** the needed permissions into `settings.json`:
   - Preserve any existing content (like `enabledPlugins`).
   - Create a `permissions.allow` array if it doesn't exist.
   - Native tools are plain strings (e.g., `Read`, `Write`, `Glob`). MCP tools use wildcards (e.g., `mcp__plugin_chrome-devtools-mcp_chrome-devtools__*`). Bash uses fine-grained command patterns (e.g., `Bash(npm *)`, `Bash(git *)`).
   - Only add permissions that aren't already present (skip duplicates).
5. **Write** the updated file back to `.claude/settings.json`.
6. **Compare** the old and new `permissions.allow` arrays. If any permissions were added (i.e., the new array has entries the old one didn't), **stop here** — do NOT continue processing the user's original request.
7. **If no permissions were added** (all requested permissions were already configured), proceed to actually execute the user's original request.
8. **Inform** the user:
   - **If permissions were added:** List which permissions were added (including the specific Bash command patterns) and state clearly that a Claude Code restart is required for the new permissions to take effect. Do NOT attempt to run the original request — it will fail without the restart.
   - **If no permissions were added:** Confirm that all permissions were already in place and that the original request is proceeding.

### Example

The resulting `settings.json` should look like:

```json
{
  "permissions": {
    "allow": [
      "Read",
      "Write",
      "Glob",
      "Grep",
      "Bash(npm *)",
      "Bash(git *)",
      "Bash(jest *)",
      "Bash(node *)",
      "Bash(python *)",
      "TaskCreate",
      "TaskUpdate",
      "TaskList",
      "mcp__plugin_chrome-devtools-mcp_chrome-devtools__*",
      "mcp__plugin_context7_context7__*"
    ]
  }
}
```

- **Native tools** are plain strings: `Read`, `Write`, `Glob`, `Grep`, `Agent`, `CronCreate`, etc.
- **MCP tools** use `mcp__<server-id>__*` to grant all tools from an MCP server.
- **Bash** is always restricted: `Bash(<command-pattern>)` where `<command-pattern>` is a glob matching the allowed command name(s). Never use bare `Bash` — always include a pattern.

## Notes

- This skill modifies the **local project** settings (`.claude/settings.json`), not global user settings.
- Permissions are added **without asking the user** — just do it.
- Duplicate permissions are skipped automatically.
- **Fine-grained Bash is required.** Never grant bare `Bash` — always narrow it to a command pattern like `Bash(npm *)` or `Bash(git *)`. Blanket Bash allows arbitrary shell execution, which is dangerous.
- Dangerous operations (e.g., `rm -rf`, `dd`, `:(){:|:&}`) may still require explicit confirmation regardless of permissions — this skill does not override those safety gates.
- **Stop-after-write:** If any permissions were newly added, stop immediately after writing the file. The new permissions require a Claude Code restart to take effect — attempting to continue the original request will fail. Only if all permissions were already configured should you proceed with the original request.
