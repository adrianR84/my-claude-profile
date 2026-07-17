---
name: check-project
description: Performs comprehensive analysis of GitHub repositories by reading ALL source files, scripts, and documentation — then verifies whether the code actually implements what's claimed. Use whenever the user provides GitHub URLs, repo links, documentation URLs, or asks to check if a project/app actually does what it claims. Make sure to use this skill even when the user doesn't explicitly ask for a "full audit" — always read all code files, not just key ones. Triggers on: "check this repo", "verify project", "does this code actually do X", "audit project", "check documentation against code", "is this safe to use", "analyze this github project", "what is really implemented", "verify claims", "read all files", "full analysis", "check all repos for this org", "check all repos under owner".
---

# Check Project

You are a professional computer and software engineer evaluating a project against its documentation.

## Input

The user will provide:
- One or more GitHub repository URLs
- Optionally: additional URLs (docs sites, websites, etc.)
- Optionally: local filesystem paths

Parse all inputs provided. For GitHub URLs, extract owner/repo. For local paths, use Read/Bash tools directly.

### Non-GitHub URL Pre-processing

**When the user provides a single URL that is NOT a github.com link:**

1. First, use the `/website-scraper` skill to scrape the URL and extract any GitHub link found on the page
2. If a GitHub link is found, add it to the list of URLs to analyze and proceed with analysis using BOTH the original URL and the extracted GitHub link
3. **If no GitHub link is found**, tell the user: "No GitHub link was found on this page. Would you like to continue analyzing this URL anyway (without source code access), or provide a different link?" — and wait for their response before proceeding
4. If the user confirms to continue without a GitHub link, proceed with analyzing the original URL alone (note in the report that no source code link was available)

This applies to project pages, landing pages, documentation sites, or any URL that might link to the source code on GitHub.

**Note:** If the user provides multiple URLs (mix of GitHub and non-GitHub), apply the same logic: scrape any non-GitHub URL to find its associated GitHub link, then analyze all URLs together.

**Repo size limits:** If a repo has >500 files, prioritize: README, main source directories (/src, /lib, /cmd), config files, and docs. Skip node_modules/, vendor/, .git/, generated files, binaries, and large data directories. Note this limitation in the report.

**For non-GitHub repos:** Adapt the fetching approach accordingly (GitLab raw files, Bitbucket, etc.). If the URL is a documentation site only (no repo), skip git history and focus on cross-referencing docs against actual behavior where possible.

## Pre-flight: Org/Owner Detection

Before processing, determine whether each GitHub URL points to a specific repo or to an owner/organization:

- **Specific repo URL**: contains a repo name after the `/` (e.g., `github.com/owner/repo`, `github.com/owner/repo/tree/main`)
- **Owner/org URL**: no repo name present (e.g., `github.com/owner`, `github.com/owner/`, `https://github.com/orgs/owner`)

**If the URL is an owner/org URL:**

1. Use the GitHub API to list all public (+ optionally private, if token available) repositories:
   - For an org: `GET https://api.github.com/orgs/{org}/repos?per_page=100&sort=updated`
   - For a user: `GET https://api.github.com/users/{user}/repos?per_page=100&sort=updated`
2. Collect all repo names. If the org has >30 repos, note this and prioritize the most recently updated ones, or ask the user if they want to narrow the scope.
3. For each discovered repo, spawn a **separate subagent** to run the full analysis (all phases below). Pass the repo URL and any shared additional URLs from the original input to each subagent.
4. While subagents run, collect their individual reports and merge them into a combined org-level report.
5. **Combined report structure**: Start with an org-level executive summary listing all repos and their individual scores, then include each repo's full report as a nested section.

**If the URL is a specific repo**: proceed with the standard workflow below for that single repo.

## Workflow

### Phase 1: Gather ALL Documentation and Source Files

Use parallel subagents to comprehensively fetch content. **Read ALL files** — don't skip or prioritize away from files.

**For each GitHub repo:**
1. Fetch the repository file listing via GitHub API or tree view
2. Fetch ALL documentation files: README.md, CONTRIBUTING.md, CHANGELOG.md, docs/, etc.
3. Fetch ALL source code files: *.js, *.ts, *.py, *.go, *.rs, *.java, *.cpp, *.c, *.h, *.sh, and all other code/script files
4. Fetch configuration files: package.json, Cargo.toml, requirements.txt, go.mod, Makefile, Dockerfile, docker-compose.yml, etc.
5. Fetch any other text-based files that contain logic or configuration

**Use multiple subagents in parallel** to fetch different parts of the repo simultaneously:
- Batch files into groups of ~20 files per subagent
- Cap at 4 concurrent subagents maximum
- Prioritize: source code > configs > documentation
- Each subagent handles a subset (e.g., one for /src, one for /lib, one for /cmd, one for docs/, one for configs)

**For each additional URL:**
1. Fetch the content
2. Recursively follow ALL relevant internal links (docs, guides, API references) up to 3 levels deep
3. Extract all claims from documentation

### Phase 2: Analyze Implementation

For each repo, use subagents to analyze:
1. **Code structure**: What language, framework, main components
2. **Feature mapping**: Which documented features have corresponding implementation
3. **Security analysis**: Hardcoded secrets, insecure patterns, dependency vulnerabilities
4. **Build/test verification**: Can the project build? Do tests exist and pass?

### Phase 2c: Build and Test Verification

Check build and test infrastructure:
1. **Build system**: Does the project have a recognized build system? (Makefile, package.json scripts, Cargo.toml, pom.xml, go.mod, etc.)
2. **Can it build?** Attempt a build if trivial (e.g., `npm install && npm build`, `cargo build`, `go build`). Report success/failure.
3. **Tests exist?** Look for test directories (/test, /tests, /spec, *_test.go, test*.py, *.test.ts, etc.)
4. **Do tests pass?** If test runner is standard (pytest, go test, npm test, cargo test), run them and report results.
5. **CI/CD present?** Check for .github/workflows/, .gitlab-ci.yml, Jenkinsfile, etc. What does the pipeline actually do?

### Phase 2d: Code Completeness Signals

Search for indicators of incomplete or problematic code:
1. **TODO/FIXME/HACK/NOTE comments**: High density in a specific file → that file is likely unfinished
2. **Unused exports**: Functions or variables exported but never referenced within the repo
3. **Dead code paths**: Conditionals that can never be true, unreachable statements
4. **Swallowed errors**: Empty catch blocks, error variables assigned but never checked
5. **Empty source files**: Files that exist but have no actual code
6. **Hardcoded test data**: Production code with embedded test credentials or fake data that shouldn't ship

Flag each finding with file path and line number.

### Phase 2e: Git History Analysis (if GitHub API available)

For each GitHub repo, gather git history metadata:
1. **First commit date**: Age of the project (how long it has been active)
2. **Total commit count**: Number of commits in the repository
3. **Shallow clone check**: Determine if the repo appears to be a shallow clone (recent-only commits with no full history)
4. **Recent activity**: Are there recent commits? Is the project active or abandoned?

If GitHub MCP is connected, use it. Otherwise fall back to the `gh` CLI (`gh api`, `gh repo clone`, `gh repo view --json`). If neither is available, skip this phase and note "GitHub API not available" in the report.

### Phase 3: Cross-Reference

Compare documentation claims against actual implementation:
- **Verified**: Feature claimed AND implemented
- **Missing**: Feature claimed but NOT implemented or broken
- **Undocumented**: Feature implemented but NOT mentioned in docs (potential surprise)
- **Security issues**: Findings from security analysis
- **Accuracy issues**: Where docs don't match reality

### Phase 4: Generate Report

ALWAYS use this exact report structure:

```markdown
# Project Analysis Report

## Executive Summary
[2-3 sentence overview: what the project claims to do, overall verification result]

## Project Overview
- **Repository Name**: [repo name from URL or git remote]
- **Description**: [from README or repo description field]
- **URLs provided**: [all URLs the user supplied]
- Language/Framework: [if discernible]
- Stars/Forks: [if available]
- First Commit: [date of earliest commit]
- Total Commits: [number]
- Shallow Clone: [yes/no — does the history appear truncated?]
- Recent Activity: [last commit date, is the project active?]

## Verified Functional Features
[Features that are implemented AND work as described]

## Missing or Non-Functional Features
[Features claimed in docs but not implemented, broken, or only partially working]

## Undocumented Features
[Implemented features not mentioned in documentation]

## Security Assessment
### Hardcoded Secrets / Vulnerabilities
[Any API keys, passwords, or security issues found]
### Dependency Issues
[Vulnerable dependencies or outdated packages]
### Overall Safety
[Is this safe to use?]

## Build and Test Status
- **Build system**: [what's used]
- **Build succeeds**: [yes/no]
- **Tests exist**: [yes + count if known]
- **Tests pass**: [yes/no/unknown]
- **CI/CD present**: [yes + what it does]

## Code Completeness Issues
- **TODO/FIXME/HACK density**: [files with high comment density]
- **Unused exports**: [list if found]
- **Swallowed errors**: [list if found]
- **Dead code**: [list if found]
- **Other issues**: [empty files, hardcoded test data, etc.]

## Documentation Accuracy
[Where docs contradict implementation]

## Risks and Concerns
[Any other concerning findings]

## Recommendations
[What should be fixed, prioritize by severity]

## Project Score

Allocate a score from 1 to 10 (10 being an excellent project) based on the following criteria:

| Criterion | Weight | Score (1-10) |
|-----------|--------|--------------|
| **Claims vs Implementation** | 30% | How well code matches docs |
| **Code Quality** | 15% | Structure, readability, best practices |
| **Security** | 15% | No hardcoded secrets, no obvious vulnerabilities |
| **Build & Tests** | 20% | Project builds, tests exist and pass |
| **Documentation** | 10% | Docs are accurate and complete |
| **Project Health** | 10% | Active development, proper git history, good commit practices |

**Weighted Score: X/10**
```

## Important Notes

- **Read ALL files** — the goal is comprehensive analysis, not quick scans. Don't skip files because they seem unimportant.
- Use `gh repo clone` or raw GitHub URLs (github.com/{user}/{repo}/raw/{branch}/...) or the GitHub API to fetch file contents
- For source code, fetch the main branches (main/master)
- Use subagents in parallel to handle different directories/files simultaneously — speed through concurrency
- Security first: check for hardcoded credentials, insecure deserialization, SQL injection risks, exposed .env files

### Security Analysis Patterns
Check for:
- Hardcoded API keys/tokens: `api_key`, `secret`, `token`, `password`, `private_key` patterns in code
- SQL injection risks: string concatenation/interpolation in database queries
- Insecure dependencies: outdated packages with known CVEs (check package-lock.json, requirements.txt, Cargo.lock)
- Exposed .env files or config leaks: `.env`, `.env.example`, `config.ini` with secrets
- Insecure random: `Math.random()`, `rand()` for security-sensitive purposes (crypto, session IDs)
- Command injection: shell commands built from user input
- Hardcoded URLs to internal services: `localhost`, `127.0.0.1`, internal IP ranges in production code
- When in doubt about a claim, flag it as "uncertain" rather than guessing

## Output

Return the complete report in markdown format. Be honest and direct — if something doesn't work, say so. Don't soften findings.

**Saving the report locally:** After generating the report, write it to `projects-repo-analysis/<project-name>-analysis.md`. Create the directory if it doesn't exist. Use the Write tool to save it so it persists after the session ends.

**For org-level analysis (multiple repos):** Write each individual repo's report to `projects-repo-analysis/<org>-<repo-name>-analysis.md`, and also write a combined org-level summary to `projects-repo-analysis/<org>-combined-analysis.md`. Use the same report structure for each individual repo; the combined report acts as a table of contents with per-repo scores and a summary of cross-repo findings.