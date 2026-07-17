# Agent Configuration

## Shell / Cross-Platform Compatibility

- **Cross-platform first**: Windows (Git Bash/MSYS2), Linux, macOS. POSIX-compliant patterns. No OS-specific commands or paths.
- **Bash 3.2 maximum**: Shell scripts must work with bash 3.2 (default on macOS). Bash 4.0+ features NOT allowed in shared scripts.
- **Prefer Node.js over shell scripts**: Node.js when task can use Node.js or shell script. Native cross-platform, faster repeated invocations, standard APIs (`fetch`, `fs`, `path`) handle OS paths correctly. Shell scripts only when Node.js unavailable or impractical.
- **Built-in tools first**: Use Claude Code built-in tools (Read, Edit, Glob, Grep, Bash) before external commands or scripts. Lightweight, avoids process spawn overhead.

## Plans

Write plans to `<project>/.claude/PLANS/<slug>.md` — descriptive, kebab-case names (e.g. `add-proxy-provider.md`, `cache-redesign.md`). Path is relative to the current project root.

## Package Management

Node.js: `pnpm` (not `npm`/`yarn`). Python: `uv` (not `pip`/`conda`/`poetry`).

## Obsidian Vault

All vaults are located at `C:\Users\adria\.obsidian`. If no vault is specified, default to **Learn**.

Other vaults may exist — ask if you need to use a different one.

## Language

Write ALL instructions, settings, skills, code comments, documentation in **English**, regardless of user's language. Ensures shared codebase accessible to all contributors.

## Coding Guidelines

1. **Before writing any code**, describe approach and wait for approval. Ask clarifying questions before writing any code if requirements ambiguous.
2. **If task requires changes to more than 3 files**, stop and break into smaller tasks first.
3. **After writing code**, list what could break and suggest tests to cover it.
4. **When there's a bug**, write test that reproduces it, then fix until test passes.
5. **Every time I correct you**, add new rule to CLAUDE.md so it never happens again.

# Agent Guidelines

Behavioral guidelines. Merge with project-specific instructions.

**Tradeoff:** Bias caution over speed. Trivial tasks use judgment.

## 1. Think Before Coding

Don't assume. Don't hide confusion. Surface tradeoffs.

Before implementing:
- State assumptions. Uncertain? Ask.
- Multiple valid interpretations? Present all, don't pick silently.
- Simpler approach exists? Say so. Push back when warranted.
- Something unclear? Stop. Name confusion. Ask.

## 2. Simplicity First

Minimum code solving problem. Nothing speculative.

- No features beyond what was asked.
- No abstractions for single-use code.
- No "flexibility" or "configurability" not requested.
- No error handling for impossible scenarios.
- 50 lines solve it? Don't write 200.

Ask: "Senior engineer call this overcomplicated?" If yes, rewrite.

## 3. Surgical Changes

Touch only what must be touched. Clean up only own mess.

When editing:
- Don't "improve" adjacent code, comments, formatting.
- Don't refactor things that aren't broken.
- Match existing style, even if you'd do differently.
- Unrelated dead code? Mention it, don't delete it.

When changes create orphans:
- Remove imports/variables/functions YOUR changes made unused.
- Don't remove pre-existing dead code unless asked.

Test: every changed line traces to user's request.

## 4. Goal-Driven Execution

Define success criteria. Loop until verified.

Transform tasks into verifiable goals:
- "Add validation" → "Write tests for invalid inputs, then make them pass"
- "Fix bug" → "Write test reproducing it, then make it pass"
- "Refactor X" → "Ensure tests pass before and after"

Multi-step tasks:
```
1. [Step] → verify: [check]
2. [Step] → verify: [check]
3. [Step] → verify: [check]
```

Strong criteria → independent loops. Weak criteria ("make it work") → constant clarification needed.

## 5. Execution Discipline

- **Read before editing**: Read full file before editing. Plan all changes, then make ONE complete edit. If you've edited file 3+ times, stop and re-read requirements.
- **Follow through**: Re-read user's last message before responding. Complete every instruction fully.
- **Stay on track**: Every few turns, re-read original request to ensure no drift from goal.
- **Ask when stuck**: When stuck, summarize what you've tried and ask user for guidance instead of retrying same approach.
- **Accept corrections**: When user corrects you, stop and re-read their message. Quote back what they asked for and confirm before proceeding.
- **Fail fast**: After 2 consecutive tool failures, stop and change approach entirely. Explain what failed and try different strategy.
- **Verify output**: Double-check output before presenting. Verify changes actually address what user asked for.
- **Work autonomously**: Make reasonable decisions without asking for confirmation on every step.

## 6. Minimize Permission Prompts

Prefer built-in tools (Read, Edit, Glob, Grep) — no process spawn overhead.
Batch edits into fewer calls rather than many small ones.

## Git

**Git commits and pushes: only when the user explicitly requests them.** Do not commit or push unprompted — the user manages the git lifecycle.

## Web Fetching

When fetching web content, prefer WebFetch. If WebFetch fails (e.g., 402, 403, or empty response), fall back to `defuddle parse <url> --md` — it strips ads/navigation and produces clean markdown at lower token cost.

---

Working if: fewer unnecessary diffs, fewer rewrites, clarifying questions before mistakes.
