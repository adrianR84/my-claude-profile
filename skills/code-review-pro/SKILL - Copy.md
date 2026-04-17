---
name: code-review-pro
description: Comprehensive code review covering security vulnerabilities, performance bottlenecks, best practices, and refactoring opportunities. Use when user requests code review, security audit, or performance analysis.
---

# Code Review Pro

Deep code analysis covering security, performance, maintainability, and best practices.

## When to Use This Skill

Activate when the user:
- Asks for a code review
- Wants security vulnerability scanning
- Needs performance analysis
- Asks to "review this code" or "audit this code"
- Mentions finding bugs or improvements
- Wants refactoring suggestions
- Requests best practice validation

## Instructions

1. **Security Analysis (Critical Priority)**
   - SQL injection vulnerabilities
   - XSS (cross-site scripting) risks
   - Authentication/authorization issues
   - Secrets or credentials in code
   - Unsafe deserialization
   - Path traversal vulnerabilities
   - CSRF protection
   - Input validation gaps
   - Insecure cryptography
   - Dependency vulnerabilities

2. **Performance Analysis**
   - N+1 query problems
   - Inefficient algorithms (check Big O complexity)
   - Memory leaks
   - Unnecessary re-renders (React/Vue)
   - Missing indexes (database queries)
   - Blocking operations
   - Resource cleanup (file handles, connections)
   - Caching opportunities
   - Excessive network calls
   - Large bundle sizes

3. **Code Quality & Maintainability**
   - Code duplication (DRY violations)
   - Function/method length (should be <50 lines)
   - Cyclomatic complexity
   - Unclear naming
   - Missing error handling
   - Inconsistent style
   - Missing documentation
   - Hard-coded values that should be constants
   - God classes/functions
   - Tight coupling

4. **Best Practices**
   - Language-specific idioms
   - Framework conventions
   - SOLID principles
   - Design patterns usage
   - Testing approach
   - Logging and monitoring
   - Accessibility (for UI code)
   - Type safety
   - Null/undefined handling

5. **Bugs and Edge Cases**
   - Logic errors
   - Off-by-one errors
   - Race conditions
   - Null pointer exceptions
   - Unhandled edge cases
   - Timezone issues
   - Encoding problems
   - Floating point precision

6. **Provide Actionable Fixes**
   - Show specific code changes
   - Explain why change is needed
   - Include before/after examples
   - Prioritize by severity
   - Always include the file path and line number for each issue

## Output Format

```markdown
# Code Review Report

## 📁 Files Reviewed
- `src/auth/login.js`
- `src/api/users.js`
- `src/utils/validation.js`

---

## 📄 File: src/auth/login.js
**Issues found: 3** | Critical: 1 | High: 1 | Medium: 1 | Low: 0

### 🚨 Critical Issues
#### 1. SQL Injection Vulnerability (line 42)
**Severity**: Critical
**Issue**: User input directly concatenated into SQL query
**Impact**: Database compromise, data theft

**Current Code:**
```javascript
const query = `SELECT * FROM users WHERE email = '${userEmail}'`;
```

**Fixed Code:**
```javascript
const query = 'SELECT * FROM users WHERE email = ?';
db.query(query, [userEmail]);
```

**Explanation**: Always use parameterized queries to prevent SQL injection.

### ⚠️ High Priority Issues
#### 2. Missing Rate Limiting (line 15)
[Details...]

### 💡 Medium Priority Issues
#### 3. Function Too Long (line 50-80)
[Details...]

---

## 📄 File: src/api/users.js
**Issues found: 2** | Critical: 0 | High: 1 | Medium: 1 | Low: 0

### ⚠️ High Priority Issues
#### 1. N+1 Query Problem (line 23)
[Details...]

### 💡 Medium Priority Issues
#### 2. Missing Index on Query (line 45)
[Details...]

---

## 📊 Overall Summary
- **Total Issues**: 12
  - Critical: 2
  - High: 4
  - Medium: 4
  - Low: 2
- **Files Reviewed**: 3
- **Files with Issues**: 2

## 📈 Issues by File
| File | Issues | Critical | High | Medium | Low |
|------|--------|----------|------|--------|-----|
| `src/auth/login.js` | 3 | 1 | 1 | 1 | 0 |
| `src/api/users.js` | 2 | 0 | 1 | 1 | 0 |
| `src/utils/validation.js` | 0 | 0 | 0 | 0 | 0 |

## 🎯 Quick Wins
Changes with high impact and low effort:
1. [Fix 1 - src/auth/login.js:42]
2. [Fix 2 - src/api/users.js:23]

## 🏆 Strengths
- Good error handling in X
- Clear naming conventions
- Well-structured modules

## 🔄 Refactoring Opportunities
1. **Extract Method**: Lines X-Y in `src/auth/login.js` could be extracted into `calculateDiscount()`
2. **Remove Duplication**: [specific code blocks]

## 📚 Resources
- [OWASP SQL Injection Guide](https://...)
- [Performance Best Practices](https://...)
```

## Examples

**User**: "Review this authentication code"
**Response**: Analyze auth logic → Identify security issues (weak password hashing, no rate limiting) → Check token handling → Note missing CSRF protection → Provide specific fixes with code examples → Prioritize by severity

**User**: "Can you find performance issues in this React component?"
**Response**: Analyze component → Identify unnecessary re-renders → Find missing useMemo/useCallback → Note large state objects → Check for expensive operations in render → Provide optimized version with explanations

**User**: "Review this API endpoint"
**Response**: Check input validation → Analyze error handling → Test for SQL injection → Review authentication → Check rate limiting → Examine response structure → Suggest improvements with code samples

## Best Practices

- Always prioritize security issues first
- Provide specific line numbers for issues
- Include before/after code examples
- Explain *why* something is a problem
- Consider the language/framework context
- Don't just criticize—acknowledge good code too
- Suggest gradual improvements for large refactors
- Link to documentation for recommendations
- Consider project constraints (legacy code, deadlines)
- Balance perfectionism with pragmatism
- Focus on impactful changes
- Group similar issues together
- Make recommendations actionable
- **Track the file path for every issue found**
- **Organize report by file first, then by severity within each file**
