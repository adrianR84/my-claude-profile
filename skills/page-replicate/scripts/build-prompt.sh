#!/usr/bin/env python3
"""build-prompt.sh rewritten in Python — no bash edge cases."""
import sys, os, json, datetime, re, subprocess
from pathlib import Path

SKILL_DIR = Path(__file__).resolve().parent.parent
WORK = Path(os.environ.get("TMPDIR", "/tmp")) / "page-replicate"
WORK.mkdir(parents=True, exist_ok=True)

url     = None
deep    = False
output  = "./page-replicate-prompt.md"

args = sys.argv[1:]
while args:
    a = args.pop(0)
    if a == "--deep":
        deep = True
    elif a == "--output":
        output = args.pop(0)
    else:
        url = a

if not url:
    print("Usage: build-prompt.py <url> [--deep] [--output <path>]", file=sys.stderr)
    sys.exit(1)

# Step 1: normalize resources
res_js = WORK / "resources.json"
norm_json = WORK / "normalized.json"
if res_js.exists():
    try:
        import nodejs as _  # noqa: F401
    except ImportError:
        pass
    result = subprocess.run(
        ["node", str(SKILL_DIR / "scripts" / "extract-resources.js"),
         str(res_js), str(norm_json)],
        capture_output=True, timeout=10
    )

# Step 2: library detection
libs_json = WORK / "libs.json"
r = subprocess.run(
    ["python3", str(SKILL_DIR / "scripts" / "identify-libs.py")],
    capture_output=True, text=True, timeout=10
)
libs_json.write_text(r.stdout if r.returncode == 0 else "{}")

# Step 3: class frequency from snapshot
snap_txt = WORK / "snapshot.txt"
class_freq = WORK / "class-freq.txt"
if snap_txt.exists():
    try:
        text = snap_txt.read_text(errors="replace")
        classes = re.findall(r'class="([^"]+)"', text)
        flat = " ".join(classes).split()
        from collections import Counter
        counts = Counter(flat)
        top = [(c, n) for n, c in sorted(counts.items(), reverse=True) if n >= 3]
        class_freq.write_text("\n".join(f"{n:>5}  {c}" for n, c in top[:50]))
    except Exception:
        class_freq.write_text("")
else:
    class_freq.write_text("")

# Step 4: --deep: curl external CSS/JS
if deep:
    inlined_dir = WORK / "inlined"
    inlined_dir.mkdir(exist_ok=True)
    norm = json.loads(norm_json.read_text()) if norm_json.exists() else {}
    urls = []
    for s in norm.get("stylesheets", []) + norm.get("scripts", []):
        u = s.get("url", "")
        if u and not u.startswith("data:"):
            urls.append(u)
    failures_log = inlined_dir / "failures.log"
    failures_log.write_text("")
    for i, u in enumerate(urls[:20]):
        fname = re.sub(r"[^a-zA-Z0-9._-]", "_", u)[:200]
        r = subprocess.run(
            ["curl", "--max-time", "10", "--max-filesize", str(2*1024*1024),
             "-sSL", u, "-o", str(inlined_dir / fname)],
            capture_output=True, timeout=15
        )
        if r.returncode != 0:
            failures_log.write_text(f"FETCH_FAILED: {u}\n", mode="a")

# Step 5: synthesize markdown (delegate to build-prompt.py)
sys.exit(subprocess.run(
    ["python3", str(SKILL_DIR / "scripts" / "build-prompt.py"),
     url, output, str(WORK), "1" if deep else "0", str(SKILL_DIR)]
).returncode)
