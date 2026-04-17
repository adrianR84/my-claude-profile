---
name: code-review-pro
description: Comprehensive code review covering security vulnerabilities, performance bottlenecks, best practices, and refactoring opportunities. Use when user requests code review, security audit, or performance analysis. TRIGGERS for: "review this code", "analyze files", "find bugs and issues", "security audit", "deep code analysis", "check for issues", "audit code", "parallel code review"
context: fork
---

# Code Review Pro

Deep parallel code analysis using distributed agents — each file is reviewed independently by a dedicated subagent, then all findings are merged into a single compacted report.

## Workflow

### Step 1: Identify Files to Review

Parse the user's request to determine which files need review. Handle globs patterns like `**/*.js` by expanding them first. If no specific files, ask the user to clarify.

**Output of this step**: A list of file paths to review.

### Step 2: Spawn Parallel Review Agents

For **each file** in the list, spawn a **separate subagent** in the same turn using `subagent_type: "general-purpose"`. Pass the file path and all review instructions to each subagent.

**Agent prompt template** (customize per file):
```
Execute this deep code review task:

**File to review**: PATH/TO/file.ext

**Instructions**:
Perform a comprehensive code review of this file covering ALL of the following categories:

1. **Security Analysis (Critical Priority)**
   - SQL injection, XSS, authentication issues, secrets in code
   - Unsafe deserialization, path traversal, CSRF, input validation gaps
   - Insecure cryptography, dependency vulnerabilities

2. **Performance Analysis**
   - N+1 query problems, inefficient algorithms (Big O complexity)
   - Memory leaks, unnecessary re-renders (React/Vue)
   - Missing indexes, blocking operations, resource cleanup issues
   - Caching opportunities, excessive network calls, large bundle sizes

3. **Code Quality & Maintainability**
   - Code duplication (DRY), function length (>50 lines is suspect)
   - Cyclomatic complexity, unclear naming
   - Missing error handling, inconsistent style
   - Hard-coded values, god classes/functions, tight coupling

4. **Best Practices**
   - Language-specific idioms, framework conventions
   - SOLID principles, design patterns usage
   - Testing approach, logging/monitoring
   - Accessibility, type safety, null/undefined handling

5. **Bugs and Edge Cases**
   - Logic errors, off-by-one errors, race conditions
   - Null pointer exceptions, unhandled edge cases
   - Timezone issues, encoding problems, floating point precision

6. **Actionable Fixes**
   - Show specific code changes with before/after
   - Include exact file path and line numbers
   - Explain WHY each change is needed
   - Prioritize by severity (Critical > High > Medium > Low)

**Deep dive requirements**:
- Read the ENTIRE file content before analyzing
- Trace function call chains to understand data flow
- Identify implicit dependencies and assumptions
- Check for TODOs/FIXMEs that indicate technical debt
- Look for commented-out code that should be removed
- Verify error handling is comprehensive
- Check that cleanup code (finally blocks, try-with-resources) is correct

**Output format** (MUST follow exactly):
Return a JSON object with this structure:
{
  "file": "PATH/TO/file.ext",
  "issues": [
    {
      "category": "Security|Performance|Code Quality|Best Practices|Bugs",
      "severity": "Critical|High|Medium|Low",
      "title": "Short descriptive title",
      "location": "line N or line N-M",
      "description": "What the issue is",
      "impact": "Why this matters",
      "current_code": "The problematic code snippet",
      "fixed_code": "The recommended fix",
      "explanation": "Why this fix addresses the issue"
    }
  ],
  "summary": {
    "total": N,
    "critical": N,
    "high": N,
    "medium": N,
    "low": N
  },
  "strengths": ["List of good practices found"],
  "file_specific_insights": "Any insights specific to this file's purpose/domain"
}

Save the JSON output to: .code_review/file_REVIEW.json
Where "file_REVIEW" is the filename without path, e.g., "login.js_REVIEW.json"

IMPORTANT: Use subagent_type: "general-purpose" when spawning this agent.
```

**Spawn ALL agents in a single turn** — use run_in_background: false for foreground execution so you receive results before aggregating.

### Step 3: Aggregate Results

After ALL subagents complete (you will receive notifications for each), read all the JSON review files and merge them.

**Aggregation rules**:
1. **Group by category** — merge all issues by category (Security, Performance, etc.)
2. **Sort within category** — by severity (Critical → High → Medium → Low), then by file
3. **Deduplicate** — if multiple agents report the same issue type, consolidate
4. **Build summary stats** — count total/critical/high/medium/low across all files
5. **Generate compacted report**

**Save complete report**:
- Save the FULL aggregated report (with ALL categories: Security, Performance, Code Quality, Best Practices, Bugs) to: `.code_review/_complete_report_TIMESTAMP_.json`
- The timestamp should be in format: `YYYYMMDD_HHMMSS` (e.g., `20260414_143052`)
- Include all categories in the saved JSON file

### Step 4: Output User-Facing Report (Simplified)

**IMPORTANT**: For the user's display, show ONLY:
- **Security Issues** section (with all severity levels)
- **Overall Summary** table
- **Issues by File** table
- **Quick Wins**
- **Strengths**

**HIDDEN from user** (but included in saved report):
- Performance Issues
- Code Quality Issues
- Best Practices Issues
- Bug & Edge Case Issues

These hidden categories are still analyzed and saved, but not shown to the user in the output.

```markdown
# Code Review Report — [Project/Scope]

## Files Reviewed
- `src/auth/login.js`
- `src/api/users.js`
- `src/utils/validation.js`

**Total files**: 3 | **Total issues**: 12

---

## 🔒 Security Issues (3)
### 🚨 Critical (1)
#### 1. SQL Injection — `src/auth/login.js:42`
**Issue**: User input directly concatenated into SQL query
**Impact**: Database compromise, data theft
**Current**:
```javascript
const query = `SELECT * FROM users WHERE email = '${userEmail}'`;
```
**Fix**:
```javascript
const query = 'SELECT * FROM users WHERE email = ?';
db.query(query, [userEmail]);
```
**Explanation**: Always use parameterized queries.

### ⚠️ High (2)
[Continue with severity sorting within category...]

---

## 📊 Overall Summary
| Metric | Value |
|--------|-------|
| Total Issues | 12 |
| Critical | 2 |
| High | 4 |
| Medium | 4 |
| Low | 2 |
| Files Reviewed | 3 |

## 📈 Issues by File
| File | Total | Critical | High | Medium | Low |
|------|-------|----------|------|--------|-----|
| `src/auth/login.js` | 3 | 1 | 1 | 1 | 0 |
| `src/api/users.js` | 2 | 0 | 1 | 1 | 0 |
| `src/utils/validation.js` | 0 | 0 | 0 | 0 | 0 |

## 🎯 Quick Wins (High Impact, Low Effort)
1. Fix SQL injection — `src/auth/login.js:42` — Critical
2. Add rate limiting — `src/auth/login.js:15` — High

## 🏆 Strengths
- Good error handling in auth flow
- Clear naming conventions
- Well-structured modules

---

*Full report (including Performance, Code Quality, Best Practices, and Bug categories) saved to `.code_review/_complete_report_TIMESTAMP_.json`*
```

**NOTE for complete report JSON**: Save the full aggregated data including all categories as JSON with this structure:
```json
{
  "generated_at": "YYYYMMDD_HHMMSS",
  "files_reviewed": ["file1", "file2"],
  "all_issues_by_category": {
    "Security": [...],
    "Performance": [...],
    "Code Quality": [...],
    "Best Practices": [...],
    "Bugs": [...]
  },
  "summary": {
    "total": N,
    "critical": N,
    "high": N,
    "medium": N,
    "low": N,
    "by_category": {...}
  },
  "strengths": [...],
  "quick_wins": [...],
  "refactoring_opportunities": [...]
}
```

## Examples

**User**: "Review all JavaScript files in src/"
**Response**:
1. Expand `src/**/*.js` → identify all files
2. Spawn 5 parallel agents with subagent_type: "general-purpose" (one per file)
3. Wait for all results
4. Aggregate into categorized report

**User**: "Analyze auth.js and api.js for security"
**Response**:
1. Identify 2 files
2. Spawn 2 parallel agents
3. Aggregate security findings

## Best Practices

- **Always spawn agents in parallel** — never sequential
- **One agent per file** for accurate per-file attribution
- **Wait for ALL agents** before aggregating
- **Save complete report** to `.code_review/_complete_report_TIMESTAMP_.json` with ALL categories
- **User display is simplified** — only show Security Issues, Overall Summary, Issues by File, Quick Wins, and Strengths
- **Group by category, sort by severity** in final report
- **Include file path in every issue** for traceability
- **Make fixes actionable** — show before/after code
- **Explain WHY** not just WHAT is wrong
- **Acknowledge strengths** alongside issues
- **Keep report compact** — no redundant explanations
