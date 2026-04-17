---
name: create-AGENTS.md
description: Create a new AGENTS.md file alongside a CLAUDE.md that references it. Trigger whenever the user says "create AGENTS.md", "set up AGENTS.md", "create agent config", or asks to bootstrap agent documentation files. This skill creates a minimal AGENTS.md and CLAUDE.md pair for establishing agent behavior documentation in a project or directory.
---

# Create AGENTS.md Skill

This skill creates an `AGENTS.md` file and a companion `CLAUDE.md` that references it via the `@AGENTS.md` include syntax.

## When to Use

- User asks to "create AGENTS.md"
- User asks to "set up AGENTS.md"
- User asks to "bootstrap agent documentation"
- User wants to establish agent configuration files in a directory

## Output Files

### AGENTS.md

Create an empty (or minimally structured) AGENTS.md file:

```markdown
# Agent Configuration

## Project Overview

## Key Conventions

## Project Structure

## Common Tasks

## Notes
```

### CLAUDE.md

Create a `CLAUDE.md` file containing only:

```markdown
@AGENTS.md
```

## Implementation

1. **Check if `AGENTS.md` exists** — if it does, skip creating it and note that in the output
2. **Check if `CLAUDE.md` exists** — if it does, skip creating it and note that in the output
3. **Create `AGENTS.md`** in the current working directory with the template only if it doesn't exist
4. **Create `CLAUDE.md`** in the current working directory with `@AGENTS.md` as its only content only if it doesn't exist
5. Report which files were created and which were skipped (already existed)
