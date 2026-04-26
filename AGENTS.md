# Agent Configuration

## Shell / Cross-Platform Compatibility

- **Cross-platform first**: Always consider Windows (Git Bash/MSYS2), Linux, macOS. POSIX-compliant patterns. No OS-specific commands or paths.
- **Bash 3.2 maximum**: Shell scripts must work with bash 3.2 (default on macOS). Bash 4.0+ features NOT allowed in shared scripts.
- **Prefer Node.js over shell scripts**: When a task can use Node.js or shell script, choose Node.js. Native cross-platform, faster repeated invocations, standard APIs (`fetch`, `fs`, `path`) handle OS paths correctly. Shell scripts only when Node.js unavailable or impractical.
- **Built-in tools first**: Use Claude Code built-in tools (Read, Edit, Glob, Grep, Bash) before reaching for external commands or scripts. Keeps things lightweight and avoids process spawn overhead.

## Package Management

Node.js: `pnpm` (not `npm`/`yarn`). Python: `uv` (not `pip`/`conda`/`poetry`).

## Obsidian Vault

Vault path: `C:\Users\adria\.obsidian\AI-Research`

## Language

Write ALL instructions, settings, skills, code comments, documentation in **English**, regardless of user's language. Ensures shared codebase accessible to all contributors.

## Coding Guidelines

1. **Before writing any code**, describe your approach and wait for approval. Always ask clarifying questions before writing any code if requirements are ambiguous.
2. **If a task requires changes to more than 3 files**, stop and break it into smaller tasks first.
3. **After writing code**, list what could break and suggest tests to cover it.
4. **When there's a bug**, start by writing a test that reproduces it, then fix it until the test passes.
5. **Every time I correct you**, add a new rule to the CLAUDE.md file so it never happens again.

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

Minimum code solving the problem. Nothing speculative.

- No features beyond what was asked.
- No abstractions for single-use code.
- No "flexibility" or "configurability" not requested.
- No error handling for impossible scenarios.
- 50 lines solve it? Don't write 200.

Ask: "Senior engineer call this overcomplicated?" If yes, rewrite.

## 3. Surgical Changes

Touch only what you must. Clean up only your own mess.

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

---

Working if: fewer unnecessary diffs, fewer rewrites, clarifying questions before mistakes.
