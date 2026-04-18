# Agent Configuration

## Environment

- **OS**: Windows 11 Home 10.0.26200
- **Terminal**: bash (Git Bash / MSYS2)

## Shell / Cross-Platform Compatibility

- **Cross-platform first**: Always consider Windows (Git Bash/MSYS2), Linux, and macOS. Use POSIX-compliant patterns. Avoid OS-specific commands or paths.
- **Bash 3.2 maximum**: All shell scripts must be compatible with bash 3.2 (default on macOS). Bash 4.0+ features are NOT allowed in shared scripts.

## Node.js Package Management

Use `pnpm` instead of `npm`/`yarn` for Node.js packages. `pnpm add`, `pnpm install`, `pnpm remove`.

## Python Package Management

Use `uv` instead of `pip`/`conda`/`poetry` for Python packages. `uv pip install`, `uv add`, `uv tool install`.

## Important

Write ALL instructions, settings, skills, program comments, code comments, documentation, and any text meant for developers in **English**, regardless of the language the user is speaking. Ensures consistency and accessibility across codebase.

# Agent Guidelines

Behavioral guidelines to reduce common LLM coding mistakes. Merge with project-specific instructions.

**Tradeoff:** Bias toward caution over speed. For trivial tasks, use judgment.

## 1. Think Before Coding

**Don't assume. Don't hide confusion. Surface tradeoffs.**

Before implementing:
- State assumptions. If uncertain, ask.
- Multiple interpretations exist? Present them, don't pick silently.
- Simpler approach exists? Say so. Push back when warranted.
- Something unclear? Stop. Name what's confusing. Ask.

## 2. Simplicity First

**Minimum code that solves the problem. Nothing speculative.**

- No features beyond what was asked.
- No abstractions for single-use code.
- No "flexibility" or "configurability" not requested.
- No error handling for impossible scenarios.
- Write 200 lines when 50 would do? Rewrite.

Ask: "Would a senior engineer say this is overcomplicated?" If yes, simplify.

## 3. Surgical Changes

**Touch only what you must. Clean up only your own mess.**

When editing:
- Don't "improve" adjacent code, comments, or formatting.
- Don't refactor things that aren't broken.
- Match existing style, even if you'd do it differently.
- Unrelated dead code? Mention it, don't delete it.

When your changes create orphans:
- Remove imports/variables/functions YOUR changes made unused.
- Don't remove pre-existing dead code unless asked.

Test: every changed line traces to user's request.

## 4. Goal-Driven Execution

**Define success criteria. Loop until verified.**

Transform tasks into verifiable goals:
- "Add validation" → "Write tests for invalid inputs, then make them pass"
- "Fix the bug" → "Write a test that reproduces it, then make it pass"
- "Refactor X" → "Ensure tests pass before and after"

For multi-step tasks:
```
1. [Step] → verify: [check]
2. [Step] → verify: [check]
3. [Step] → verify: [check]
```

Strong criteria let you loop independently. Weak criteria ("make it work") require constant clarification.

---

**Working if:** fewer unnecessary diffs, fewer rewrites, clarifying questions before mistakes.
