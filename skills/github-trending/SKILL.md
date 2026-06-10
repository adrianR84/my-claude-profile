---
name: github-trending
description: |
  Display trending GitHub repositories by time period (day/week/month) with details like name,
  stars, description, language, author, forks, and today's star gains. Use whenever the user asks
  about trending repos, what's hot on GitHub, top repos today/week/month, or similar queries.
  Triggers on: /trending, "github trending", "trending repos", "what's hot on github",
  "top repositories", "popular github repos", "hot repos"
user-invocable: true
---

# GitHub Trending Skill

Display trending GitHub repositories filtered by time period and optionally by language.

## Usage

```
/trending [day|week|month] [language]
```

**Examples:**
- `/trending` — today's trending repos
- `/trending week` — this week's trending repos
- `/trending month python` — top Python repos this month
- `/trending week javascript` — top JS repos this week

## How It Works

1. **Fetch** the GitHub trending page: `https://github.com/trending`
2. **Parse** the repository cards for name, stars, description, language, author
3. **Filter** by time period using URL parameters: `?since=daily|weekly|monthly`
4. **Filter** by language using URL path: `/trending/javascript`
5. **Format** results in a clean, readable table

## Data Retrieved Per Repo

| Field | Description |
|-------|-------------|
| Name | Repository name with author (e.g., "owner/repo") |
| Link | GitHub URL (e.g., `https://github.com/owner/repo`) |
| Stars | Total stars + "today" gain (e.g., "1.2k ★ (+120)") |
| Forks | Fork count |
| Description | Short repo description |
| Language | Programming language with color dot |
| Author | GitHub username |
| Topics | Tags/topics (if available) |
| Today's stars | Stars gained today (indicator of momentum) |

## Fetch Strategy

Use WebFetch to scrape `https://github.com/trending`:

```
# Daily trending
https://github.com/trending?since=daily

# Weekly trending
https://github.com/trending?since=weekly

# Monthly trending
https://github.com/trending?since=monthly

# With language filter
https://github.com/trending/python?since=weekly
```

If WebFetch fails, fall back to WebSearch for "GitHub trending [day/week/month] [language]" and extract results.

## Output Format

Present as a formatted list or table, sorted by today's star gains (most active first):

```
🔥 Trending GitHub Repos — Today
═══════════════════════════════════════════════════════

1. anthropic/claude-code          ★ 45.2k  (+892 today)
   AI-powered coding agent. Build, test, iterate.
   Language: TypeScript  •  Author: anthropic
   Topics: claude, ai, coding-agent
   🔗 https://github.com/anthropic/claude-code

2. microsoft/typescript            ★ 102k  (+340 today)
   TypeScript is a superset of JavaScript that compiles to clean JavaScript output.
   Language: TypeScript  •  Author: microsoft
   Topics: typescript, language, microsoft
   🔗 https://github.com/microsoft/typescript

...

───────────────────────────────────────────────────────
Showing top 25 trending repos. Time period: today.
```

## Time Period Mapping

| User input | URL parameter |
|------------|---------------|
| day, today, daily | `?since=daily` |
| week, weekly, this week | `?since=weekly` |
| month, monthly, this month | `?since=monthly` |
| (none) | defaults to `daily` |

## Language Filter

Common languages: python, javascript, typescript, java, go, rust, c++, c#, ruby, php, swift, kotlin, shell, html, css

If user specifies a language, append it to URL path: `/trending/python`

## Error Handling

- If GitHub is blocked/unavailable, use WebSearch as fallback
- If no repos found, tell user and suggest broader search
- Handle rate limiting gracefully with a message

## Anti-Patterns

- Don't show more than 25 repos (overwhelming)
- Don't include broken/malicious repos in results
- Don't use unauthenticated API calls that might rate limit
