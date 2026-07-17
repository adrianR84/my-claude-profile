---
name: page-replicate
description: |
  Extract everything from a URL needed to recreate the page as an AI prompt.
  Combines defuddle (clean HTML/markdown), WebFetch (raw HTML), chrome-devtools
  MCP (a11y tree + runtime DOM + network log), pixelbrowse (visual screenshot),
  and tavily-mcp (clean content extraction) into one structured prompt that
  captures HTML structure, all CSS/JS/images/fonts, library versions, classes,
  colors, layout, and animations.
  Triggers when the user: provides a URL and asks to "replicate", "clone", "recreate",
  "copy", or "reverse-engineer" a webpage; asks to "build a prompt from this URL";
  says "page-replicate <url>"; or asks to "extract page to prompt" or
  "analyze this page for AI reproduction". Always offer this skill when the user
  shares a URL and describes a web page they want reproduced.
allowed-tools: "Bash, Read, Write, Edit, Glob, Grep, ToolSearch"
license: MIT
metadata:
  category: web
  dependencies:
    - defuddle (CLI, npm global)
    - pixelshot (CLI, uv/pipx install pixelrag)
    - chrome-devtools-mcp (plugin MCP server)
    - mcp-tavily-mcp (skill, optional — skipped if TAVILY_API_KEY unset)
---

# page-replicate

Turn any URL into a self-contained prompt an AI can use to rebuild the page.

## How it works

Three phases run in sequence:

- **Phase 1** (parallel): defuddle, WebFetch, pixelbrowse, tavily — stateless HTTP tools
- **Phase 2** (sequential): chrome-devtools MCP — live browser sees JS-rendered DOM + CSSOM
- **Phase 3** (synthesis): scripts build the final markdown brief

## Invocation

```
/page-replicate <url>
/page-replicate <url> --output ./page-prompt.md
/page-replicate <url> --no-screenshot
/page-replicate <url> --deep
```

| Flag | Effect |
|------|--------|
| `--output <path>` | Write prompt to this path (default: `./page-replicate-prompt.md`) |
| `--no-screenshot` | Skip pixelbrowse (saves time if visual is not needed) |
| `--deep` | Fetch and inline external CSS/JS file contents (max 20 files, 2MB each) |

## Phase 1 — Parallel (stateless HTTP)

Run all four commands simultaneously. Each provides a different lens on the page.

### 1a. defuddle (clean markdown + metadata)

```bash
defuddle parse "<url>" -j > /tmp/page-replicate/defuddle.json
```

Captures: title, description, metaTags, schemaOrgData, contentMarkdown, wordCount, favicon, og:image. Install: `npm install -g defuddle`.

### 1b. WebFetch (raw HTML)

```bash
WebFetch(url="<url>", prompt="Return the full raw HTML of the page including <head> and all <script>/<link>/<style> tags. Include inline <script> and <style> contents verbatim. Do not summarize.")
```

Captures: inline `<style>` blocks, inline `<script>` blocks, `<link rel="stylesheet">` URLs, `<script src>` URLs, `<meta>` tags, `@font-face` declarations.

### 1c. pixelbrowse (visual screenshot tiles)

```bash
pixelshot "<url>" --output /tmp/page-replicate --tile-height 1568 --viewport-width 1280 --wait-network-idle
```

Read tile images with the Read tool — they are the visual ground truth. Install: `uv tool install pixelrag` or `pipx install pixelrag`. If not available, chrome-devtools `take_screenshot` is the fallback.

### 1d. tavily extract (fallback for protected sites)

```bash
<path-to-mcp-tavily-mcp>/scripts/mcp-tavily-mcp.sh tavily_extract '{"urls":["<url>"], "extract_depth":"advanced", "include_images":true}' > /tmp/page-replicate/tavily.json 2>&1 || true
```

**Skip entirely if `TAVILY_API_KEY` is unset** — check with `[ -n "$TAVILY_API_KEY" ] || echo "skip"`. Never block the pipeline on a missing API key.

## Phase 2 — chrome-devtools MCP (live browser)

Run these sequentially — each step depends on the browser state from the previous one.

### 2a. Navigate

```
mcp__chrome-devtools__navigate_page { url: "<url>", type: "url" }
```

### 2b. Wait for hydration

```
mcp__chrome-devtools__wait_for { time: 3 }
```

For SPAs, also try matching on known text from the defuddle output:
```
mcp__chrome-devtools__wait_for { text: "<unique phrase from page>" }
```
If this times out, retry with `time: 5` — some frameworks hydrate slowly.

### 2c. Accessibility snapshot (structural blueprint)

```
mcp__chrome-devtools__take_snapshot { verbose: true }
```

Save the output to `/tmp/page-replicate/snapshot.txt`. This captures headings hierarchy, landmark regions, class names, IDs, ARIA roles — everything needed to understand the DOM structure.

### 2d. Evaluate script (resource extraction)

```
mcp__chrome-devtools__evaluate_script {
  script: "() => {\n  const u = h => new URL(h, location.href).href;\n  const links = [...document.querySelectorAll('link')].map(l => ({rel: l.rel, href: u(l.href), type: l.type, as: l.as}));\n  const scripts = [...document.querySelectorAll('script[src]')].map(s => ({src: u(s.src), type: s.type, async: s.async, defer: s.defer, module: s.type==='module'}));\n  const imgs = [...document.images].map(i => ({src: u(i.src), srcset: i.srcset, alt: i.alt, w: i.naturalWidth, h: i.naturalHeight}));\n  const videos = [...document.querySelectorAll('video, video source')].map(v => ({tag: v.tagName, src: u(v.src || v.getAttribute('src')), type: v.type}));\n  const fonts = [...document.fonts].map(f => ({family: f.family, weight: f.weight, style: f.style, status: f.status}));\n  const stylesheets = [...document.styleSheets].map(s => { try { return {href: u(s.href), rules: s.cssRules ? s.cssRules.length : 0, ok: true}; } catch(e) { return {href: u(s.href), rules: 0, ok: false}; }});\n  const meta = [...document.querySelectorAll('meta')].map(m => ({name: m.name, property: m.getAttribute('property'), content: m.content}));\n  const rootVars = {};\n  for (const sheet of document.styleSheets) { try { for (const r of sheet.cssRules) { if (r.style) for (let i=0;i<r.style.length;i++) { const p = r.style[i]; if (p.startsWith('--')) rootVars[p] = r.style.getPropertyValue(p).trim(); }}} catch(e){} }\n  return JSON.stringify({title: document.title, lang: document.documentElement.lang, charset: document.characterSet, links, scripts, imgs, videos, fonts, stylesheets, meta, rootVars, viewport: {w: innerWidth, h: innerHeight, dpr: devicePixelRatio}}, null, 2);\n}"
}
```

Save stdout to `/tmp/page-replicate/resources.json`. This is the source of truth for library detection and resource listing.

### 2e. Network log (catch missed CDN assets)

```
mcp__chrome-devtools__list_network_requests { resourceTypes: ["Stylesheet","Script","Image","Font","Media"] }
```

Save to `/tmp/page-replicate/network.json` — supplement the evaluate_script results with anything it missed.

## Phase 3 — Synthesis

Run the synthesis script to produce the final markdown brief:

```bash
"$(SkillDir)/scripts/build-prompt.sh" "<url>" --output "./page-replicate-prompt.md" [--deep]
```

The script reads all `/tmp/page-replicate/*` artifacts and writes the structured prompt.

### build-prompt.sh steps

1. Read `resources.json` → normalize with `extract-resources.js`
2. Run `identify-libs.py` on resources + snapshot → library detection
3. If `--deep`: `curl` each external CSS/JS (max 20 files, 2MB, 10s timeout each)
4. Python heredoc renders the markdown brief with all 13 sections

### Output: 13-section brief

The generated prompt has these sections:

1. **Visual Reference** — paths to pixelbrowse tile screenshots
2. **Page Metadata** — title, lang, charset, viewport, meta tags, favicon, og:image
3. **Identified Libraries and Versions** — table: library, version, CDN source, purpose
4. **Detected CSS Frameworks** — class-frequency table from snapshot (Tailwind vs Bootstrap vs Foundation vs Materialize vs Bulma)
5. **All External Resources** — tables for stylesheets, scripts, images, videos, fonts
6. **HTML Structure** — condensed a11y tree (first 8000 chars)
7. **CSS — External (--deep only)** — inlined stylesheet contents, each prefixed with source URL
8. **JavaScript — External (--deep only)** — inlined script contents, each prefixed with source URL
9. **Key Styles** — CSS custom properties, color palette, typography scale, spacing
10. **Animations and Interactions** — @keyframes, transitions, event handlers
11. **Layout Structure** — landmarks (header/nav/main/aside/footer), flex/grid containers
12. **Reproduction Brief** — 200-word paragraph telling the AI how to assemble the page
13. **Open Questions / Gaps** — CORS failures, missing versions, gated assets

## Edge Cases

### Login walls
If defuddle returns < 50 words AND the snapshot has < 10 elements, print a warning in the brief:
"> **Login wall detected** — relying on pixelbrowse and chrome-devtools DOM after auth. Some assets may be gated."

### JS-rendered SPAs
Always use `wait_for { time: 3 }` before snapshot/script. If `wait_for { text: "..." }` times out, retry with `wait_for { time: 5 }`.

### CORS-blocked assets (--deep)
`curl` has no CORS restrictions — use it instead of fetch. If a server returns 403/404 or times out (>10s), mark it as `FETCH_FAILED: <url>` in the prompt rather than failing the whole build.

### No version in CDN URL
If a CDN URL matches a library but has no version (e.g. `/react/` not `/react@18.2.0/`), output `version: unknown`. Supplement with class-name detection: if the snapshot contains Tailwind class patterns (>5 hits), flag `tailwindcss: unknown` as confirmed.

### Large pages
Cap each inlined file: CSS at 200KB, JS at 50KB, with a `// TRUNCATED` marker. Cap `--deep` at 20 files total.

## Environment

- Work directory: `/tmp/page-replicate/` (or `%TEMP%\page-replicate\` on Windows)
- Output: `./page-replicate-prompt.md` (or path given by `--output`)
- Required tools: defuddle, pixelshot, chrome-devtools MCP
- Optional tools: tavily (skipped if `TAVILY_API_KEY` absent)
