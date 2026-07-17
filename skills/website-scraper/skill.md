---
name: website-scraper
description: Extract structured data from any webpage — site name, URL, social links (Twitter, GitHub, Telegram), or any user-specified elements (first H2, latest posts, prices, etc.). Use this skill whenever the user asks to get information from a website, extract webpage content, pull metadata, or find specific elements on a page. Trigger on phrases like "get website info", "extract site details", "what's on this page", "find X on this website", "scrape this page", "fetch website metadata", or any request for specific content from a URL.
---

# Website Scraper

Extract structured information from a webpage and return it as JSON.

## Fetching the webpage

1. **First try WebFetch** — use the `WebFetch` tool with the target URL
2. **If WebFetch fails or returns empty/insufficient content**, try `defuddle`:
   ```
   defuddle parse <url> --md
   ```
   If `defuddle` is not installed, use `npx defuddle parse <url> --md`
3. **If WebFetch and defuddle both fail or return no content**, use Playwright CLI — it handles JS-rendered pages reliably:
   ```
   playwright-cli open <url>
   playwright-cli eval "document.title"
   playwright-cli snapshot
   playwright-cli close
   ```
   If `playwright-cli` is not installed, use `npx --no-install playwright-cli` for all commands
   - `eval "document.title"` gets the page title (site name)
   - `snapshot` returns an accessibility tree with `/url:` fields for every link and all text content
   - Read the snapshot YAML to extract all visible text and links
4. **If all methods fail**, return a clear error message

## What to extract

**Always extract these standard fields:**
- `name` — from `<title>`, `og:site_name`, or infer from URL
- `url` — the canonical/final URL
- `twitter` — Twitter/X link (e.g. `https://x.com/username` or `https://twitter.com/username`)
- `github` — GitHub link (e.g. `https://github.com/org-name`)
- `telegram` — Telegram link (e.g. `https://t.me/username`)

**Additionally, extract any user-specified elements.** Examples:
- "first H2 heading" → add `"first_h2": "the text of the first H2"`
- "latest 3 blog posts" → add `"latest_posts": [{"title": "...", "url": "..."}, ...]`
- "hero section text" → add `"hero_text": "..."`
- "all prices" → add `"prices": ["$10", "$20", ...]`
- "contact email" → add `"email": "info@example.com"`

When extracting user-specified elements, use the most appropriate method:
- **Playwright snapshot** — best for rendered DOM content, headings, paragraphs, links
- **WebFetch/defuddle** — best for raw HTML, meta tags, structured data
- **CSS/XPath selectors via Playwright** — for specific elements: `playwright-cli eval "document.querySelector('selector').textContent"`

## Where to look

Twitter, GitHub, and Telegram links may appear in:
- Footer sections
- Navigation menus
- Community/links pages
- Documentation sidebars
- Social media sections

If not found on the main page, fetch related pages like `/community`, `/links`, `/social`, `/about`, or `/contact`.

## Heavy JS-rendered pages

**Step 1: Use Playwright CLI** (see step 3 above). The `snapshot` command executes JavaScript and returns the fully rendered accessibility tree — no need to parse HTML or inspect JS bundles.

**Step 2: If Playwright didn't return the needed info**, inspect the loaded JS files directly:
1. Use `playwright-cli network` to list network requests and find JS bundle URLs (usually in `/assets/`, `/static/`, or `/js/`)
2. Fetch those JS files with WebFetch
3. Search for patterns: GitHub URLs, Twitter/X handles (`@username`), Telegram usernames (`t.me/username`), site names, API endpoints, or any user-requested content
4. Also check `<script>` tags in the initial HTML for inline JSON data (e.g. `window.__INITIAL_DATA__`)

## Output format

**Always return TWO separate JSON blocks:**

**1. Standard JSON (never changes):**
```json
{
  "name": "Example",
  "website": "https://example.com",
  "twitter": "https://x.com/example or null",
  "github": "https://github.com/example or null",
  "telegram": "https://t.me/example or null"
}
```

**2. Extracted JSON (only when user requested custom elements):**
```json
{
  "first_h2": "The heading text",
  "hero_text": "Full hero paragraph...",
  "articles": [{"title": "Post 1", "url": "https://..."}]
}
```

Rules:
- The standard JSON format is **fixed** — always returns exactly those 5 fields
- Use `null` for social fields that cannot be found
- If no custom elements were requested, output **only** the standard JSON
- If the user requested custom elements, output the standard JSON **first**, then the extracted JSON on the next line

## Examples

**Basic — social links only:**
```
Input: https://example.com
Output:
{
  "name": "Example",
  "website": "https://example.com",
  "twitter": "https://x.com/example",
  "github": "https://github.com/example",
  "telegram": "https://t.me/example"
}
```

**With custom extraction:**
```
Input: https://news.site with first 3 article titles
Output:
{
  "name": "News Site",
  "url": "https://news.site",
  "twitter": null,
  "github": null,
  "telegram": null
}
{"articles": [
  {"title": "Article 1 Title", "url": "https://news.site/article-1"},
  {"title": "Article 2 Title", "url": "https://news.site/article-2"},
  {"title": "Article 3 Title", "url": "https://news.site/article-3"}
]}
```
