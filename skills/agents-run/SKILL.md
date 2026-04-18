---
name: agents-run
description: Spawn one or more subagents to work in parallel on the user's request. Use whenever the user asks to "run multiple agents", "parallelize", "spawn agents", "run in parallel", "use multiple agents", or when a task is complex enough to benefit from being split across several autonomous workers.
---

## Overview

This skill spawns one or more `general-purpose` subagents to fulfill the user's request in parallel. The parent agent coordinates, assigns distinct work packages to each subagent, waits for completion, and synthesizes results.

---

## When to use

- User explicitly asks to use multiple agents ("run 3 agents", "spawn parallel agents", "fork workers")
- Task is complex with independent sub-tasks that can run simultaneously
- User's request naturally breaks into distinct parts (e.g., "analyze this repo and also check the tests")
- User says "parallelize this" or "speed this up with multiple agents"

---

## How it works

### Step 1 — Parse the request

Determine:
- **How many agents** are needed (1 if simple, 2–5+ if complex/independent)
- **What each agent should do** — distinct, focused work packages
- **What the user expects back** — report, files, code, etc.

Use your judgment. Don't spawn 5 agents if 2 would do. If the task is simple and self-contained, just handle it yourself without spawning.

### Step 2 — Spawn agents

Use the `Agent` tool with `subagent_type: "general-purpose"`.

For **each** agent, provide:
- A `description` — short label for the task
- A `prompt` — complete, self-contained instructions so the agent can work without referencing the parent session
- `run_in_background: true` — run all agents in parallel

**Important:** Each agent prompt must be self-sufficient. Include all relevant context, constraints, file paths, and success criteria directly in the prompt. The subagent operates in isolation.

### Step 3 — Wait for completion

All agents run in parallel. Use `TaskOutput` to wait for each one to complete. Process results as they come in.

### Step 4 — Synthesize and report

Combine outputs into a coherent response. If agents produced files, point to them. If results conflict, summarize the disagreement and present options.

---

## Prompt design principles

Each subagent prompt should include:
1. **What to do** — clear task description
2. **What context exists** — relevant files, code, data the agent needs
3. **How to report back** — what format to return results in
4. **Constraints** — time limits, style, any boundaries

Example agent prompt:
```
You are a research agent. Your task: <task description>

Context:
- Working directory: <path>
- Relevant files: <list>
- Constraints: <any limits>

Report your findings as:
- Key discoveries
- Problems encountered
- Files created/modified
- Recommendations
```

---

## Spawning examples

**Single agent:**
```
Agent(description="Analyze repository structure", prompt="...", run_in_background=true)
```

**Multiple agents (parallel):**
```
Agent(description="Analyze backend code", prompt="...", run_in_background=true)
Agent(description="Review test coverage", prompt="...", run_in_background=true)
Agent(description="Check documentation", prompt="...", run_in_background=true)
```
Then wait for all three with `TaskOutput`.

---

## Rules

- **Never assume** an agent can access the parent session's context — include everything in the prompt
- **One task per agent** — don't conflate unrelated work into one agent
- **Report failures** — if an agent errors or produces nothing useful, say so
- **No agent controls another** — each agent is autonomous; coordinate from the parent
- **Keep agent prompts focused** — vague prompts produce vague results