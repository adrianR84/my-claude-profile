#!/usr/bin/env python3
"""Synthesizes page-replicate artifacts into a markdown brief."""
import json, sys, datetime, re
from pathlib import Path

url     = sys.argv[1]
output  = sys.argv[2]
work    = Path(sys.argv[3])
deep    = sys.argv[4] == "1"
skill_dir = Path(sys.argv[5])

def load(p, default=""):
    f = work / p
    return f.read_text(errors="replace") if f.exists() else default

def loadj(p, default=None):
    f = work / p
    return json.loads(f.read_text()) if f.exists() else (default or {})

resources = loadj("normalized.json", {})
defuddle  = loadj("defuddle.json", {})
tavily    = loadj("tavily.json", {})
libs      = loadj("libs.json", {})
classfreq = load("class-freq.txt").strip().splitlines()
tiles     = sorted(work.glob("*.png.tiles/tile_*.jpg"))

title     = defuddle.get("title") or resources.get("title") or url
login_wall = (defuddle.get("wordCount", 999) < 50) and (not resources.get("scripts"))

lines = []
def sec(n, name):
    lines.extend([f"\n## {n}. {name}\n"])

def table(headers, rows):
    if not rows:
        return "- (none)\n"
    out = "| " + " | ".join(str(h) for h in headers) + " |\n"
    out += "|" + "|".join(["---"] * len(headers)) + "|\n"
    for r in rows:
        out += "| " + " | ".join(str(c) for c in r) + " |\n"
    return out

# Header
lines.append(f"# Page Replication Brief: {title}\n")
lines.append(f"Source URL: {url}\n")
lines.append(f"Captured: {datetime.datetime.now(datetime.timezone.utc).isoformat()}\n")
if login_wall:
    lines.append("> **Login wall detected** — relying on pixelbrowse and chrome-devtools DOM. Some assets may be gated.\n")

# 1. Visual Reference
sec(1, "Visual Reference")
if tiles:
    for t in tiles:
        lines.append(f"- `{t}`")
    lines.append("\n_Read the tile images above first — they are the visual ground truth._\n")
else:
    lines.append("- _(no screenshots captured)_\n")

# 2. Page Metadata
sec(2, "Page Metadata")
vp = resources.get("viewport", {})
meta_pairs = [
    ("Title",    resources.get("title", "")),
    ("Language", resources.get("lang", "")),
    ("Charset",  resources.get("charset", "")),
    ("Viewport", f"{vp.get('w','?')}x{vp.get('h','?')} @ {vp.get('dpr','?')}x DPR"),
]
for k, v in meta_pairs:
    if v:
        lines.append(f"- **{k}:** `{v}`")
for m in resources.get("meta", [])[:20]:
    key = m.get("name") or m.get("property") or ""
    val = m.get("content", "")
    if key and val:
        lines.append(f"- **meta {key}:** {val}")
if defuddle.get("favicon"):
    lines.append(f"- **favicon:** `{defuddle['favicon']}`")
if defuddle.get("image"):
    lines.append(f"- **og:image:** `{defuddle['image']}`")

# 3. Identified Libraries
sec(3, "Identified Libraries and Versions")
if libs:
    rows = [
        (n, info.get("version", "unknown"),
         (info["sources"][0].get("url") or info["sources"][0].get("via", ""))[:80],
         info.get("kind", ""))
        for n, info in libs.items()
    ]
    lines.append(table(["Library", "Version", "Source", "Kind"], rows))
else:
    lines.append("- _(none detected — page may use vanilla HTML/CSS/JS)_\n")

# 4. Detected CSS Frameworks
sec(4, "Detected CSS Frameworks (class frequency)")
if classfreq:
    lines.append("_Class patterns from the a11y snapshot (count >= 3). High count = framework confirmed._\n")
    lines.append("```\n")
    lines.extend(classfreq[:40])
    lines.append("```\n")
else:
    lines.append("- _(no class frequency data available)_\n")

# 5. External Resources
sec(5, "All External Resources")
lines.append("### Stylesheets\n")
ss = resources.get("stylesheets", [])
if ss:
    lines.append(table(["URL", "Type"], [[s["url"][:120], s.get("type", "")] for s in ss]))
else:
    lines.append("- (none)\n")

lines.append("\n### Scripts\n")
scr = resources.get("scripts", [])
if scr:
    rows = [[s["url"][:120], str(s.get("async", "")).lower(),
             str(s.get("defer", "")).lower(), str(s.get("module", "")).lower()] for s in scr]
    lines.append(table(["URL", "Async", "Defer", "Module"], rows))
else:
    lines.append("- (none)\n")

lines.append("\n### Images\n")
imgs = resources.get("images", [])
if imgs:
    rows = [[i["url"][:120], i.get("alt", "")[:40], str(i.get("w", "")), str(i.get("h", ""))]
            for i in imgs]
    lines.append(table(["URL", "Alt", "W", "H"], rows))
else:
    lines.append("- (none)\n")

lines.append("\n### Videos / Media\n")
vids = resources.get("videos", [])
if vids:
    lines.append(table(["URL", "Type"], [[v["url"][:120], v.get("type", "")] for v in vids]))
else:
    lines.append("- (none)\n")

lines.append("\n### Fonts\n")
fnts = resources.get("fonts", [])
if fnts:
    rows = [[f["family"], f.get("weight", ""), f.get("style", "")] for f in fnts]
    lines.append(table(["Family", "Weight", "Style"], rows))
else:
    lines.append("- (none — no @font-face rules detected)_\n")

# 6. HTML Structure
sec(6, "HTML Structure (a11y snapshot)")
snap = load("snapshot.txt")
if snap:
    trunc = snap[:8000]
    lines.append("```\n" + trunc + "\n```\n")
    if len(snap) > 8000:
        lines.append(f"\n_[snapshot truncated; full snapshot at `{work}/snapshot.txt`]_\n")
else:
    lines.append("- _(no snapshot captured)_\n")

# 7 & 8. Inlined external CSS/JS (--deep only)
inlined_dir = work / "inlined"
if deep and inlined_dir.exists():
    css_files = sorted(inlined_dir.glob("*.css")) + sorted(inlined_dir.glob("*.less")) + sorted(inlined_dir.glob("*.scss"))
    js_files  = sorted(inlined_dir.glob("*.js")) + sorted(inlined_dir.glob("*.mjs"))

    sec(7, "CSS — External (inlined)")
    for f in css_files:
        content = f.read_text(errors="replace")[:200000]
        lines.append(f"\n/* FILE: {f.name} */\n```css\n{content}\n```\n")

    sec(8, "JavaScript — External (inlined)")
    for f in js_files:
        content = f.read_text(errors="replace")[:50000]
        lines.append(f"\n// FILE: {f.name}\n```javascript\n{content}\n```\n")

    failures = inlined_dir / "failures.log"
    if failures.exists() and failures.read_text().strip():
        lines.append("\n**Fetch failures:**\n```\n" + failures.read_text() + "```\n")

# 9. Key Styles
sec(9, "Key Styles")
cvars = resources.get("cssVars", {})
if cvars:
    lines.append("**CSS custom properties detected:**\n```\n")
    for k, v in list(cvars.items())[:50]:
        lines.append(f"  {k}: {v};")
    lines.append("```\n")

# 10. Animations & Interactions
sec(10, "Animations and Interactions")
lines.append(
    "- Inspect inline `<style>` blocks in the raw HTML (WebFetch output) for `@keyframes` rules.\n"
    "- Inspect inline `<script>` blocks for JS event handlers or animation library init (GSAP, Anime.js, Lottie).\n"
    "- Check chrome-devtools console for framework or animation library console messages.\n"
)

# 11. Layout Structure
sec(11, "Layout Structure")
lines.append(
    "- See the a11y snapshot in section 6 for landmarks: `<header>`, `<nav>`, `<main>`, `<aside>`, `<footer>`.\n"
    "- Flexbox containers: look for `display: flex` in inline styles or stylesheet rules.\n"
    "- Grid containers: look for `display: grid` or CSS Grid class names.\n"
)

# 12. Reproduction Brief
sec(12, "Reproduction Brief")
brief_parts = []
if libs:
    lib_parts = []
    for n, info in libs.items():
        ver = info.get("version", "?")
        ver_str = f" @{ver}" if ver != "unknown" else ""
        lib_parts.append(f"**{n}**{ver_str}")
    brief_parts.append("This page uses: " + ", ".join(lib_parts) + ".")
elif resources.get("scripts") or resources.get("stylesheets"):
    brief_parts.append("This page appears to use vanilla HTML/CSS/JS with no detected framework libraries.")

if resources.get("fonts"):
    fonts_seen = list({f["family"].strip("'\"") for f in resources.get("fonts", [])})[:6]
    fonts_str = ", ".join(f"**{f}**" for f in fonts_seen)
    brief_parts.append(f"Typography uses: {fonts_str}.")

if resources.get("stylesheets"):
    brief_parts.append(f"Loads {len(resources['stylesheets'])} external stylesheet(s) listed in section 5.")
if resources.get("scripts"):
    brief_parts.append(f"Loads {len(resources['scripts'])} external script(s) listed in section 5.")

brief_parts.append(
    "Start by reading the visual tiles in section 1 to match colors, spacing, and typography. "
    "Assemble the HTML structure from section 6, apply styles from sections 9-11, "
    "then load all external resources from section 5 before testing interactions in section 10."
)
lines.append(" ".join(brief_parts) + "\n")

# 13. Open Questions / Gaps
sec(13, "Open Questions / Gaps")
gaps = []
if not resources.get("scripts") and not resources.get("stylesheets"):
    gaps.append("- No external scripts or stylesheets detected — page may be fully server-rendered with all CSS/JS inline.")
if not resources.get("fonts"):
    gaps.append("- No @font-face rules detected — fonts may be loaded via @import in an external stylesheet (check section 5).")
if not resources.get("images"):
    gaps.append("- No <img> tags detected — hero or background images may be CSS background-image properties (check inline styles).")
if login_wall:
    gaps.append("- Login wall present — exact asset URLs behind authentication could not be extracted.")
if tavily == {}:
    gaps.append("- tavily extract unavailable (no API key or request failed).")
if gaps:
    lines.extend(gaps)
else:
    lines.append("- No major gaps detected. All resources were successfully extracted.\n")

# Write output
Path(output).parent.mkdir(parents=True, exist_ok=True)
Path(output).write_text("\n".join(lines), encoding="utf-8")
print(f"Done. Prompt written to: {output}")
