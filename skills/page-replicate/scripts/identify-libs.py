#!/usr/bin/env python3
"""Detect libraries and versions from CDN URLs and CSS class names."""
import json
import re
import sys
from pathlib import Path

SIG_PATH = Path(__file__).parent.parent / "references" / "library-signatures.json"
RES_PATH = Path("/tmp/page-replicate/resources.json")
SNAP_PATH = Path("/tmp/page-replicate/snapshot.txt")


def load_signatures():
    return json.loads(SIG_PATH.read_text())


def detect_from_urls(resources, sigs):
    found = {}
    for entry in sigs["url_patterns"]:
        pattern = re.compile(entry["pattern"])
        for kind in entry.get("scan_in", []):
            for item in resources.get(kind, []):
                url = item.get("url") or item.get("src") or ""
                m = pattern.search(url)
                if m:
                    name = entry["name"]
                    version = m.group(1) if m.lastindex and m.group(1) else "unknown"
                    if name not in found:
                        found[name] = {"version": version, "sources": [], "kind": entry.get("kind", "")}
                    found[name]["sources"].append({"url": url, "kind": kind})
                    if version != "unknown":
                        found[name]["version"] = version
    return found


def detect_from_classes(text, sigs):
    found = {}
    for fw in sigs.get("class_frameworks", []):
        count = sum(len(re.findall(rf'\b{re.escape(cls)}\b', text)) for cls in fw["classes"])
        if count >= fw.get("min_hits", 5):
            found[fw["name"]] = {
                "version": "unknown",
                "sources": [{"via": "class-detection", "count": count}],
                "kind": "css",
            }
    return found


def main():
    sigs = load_signatures()
    resources = json.loads(RES_PATH.read_text()) if RES_PATH.exists() else {}
    snapshot_text = SNAP_PATH.read_text(errors="ignore") if SNAP_PATH.exists() else ""

    from_urls = detect_from_urls(resources, sigs)
    from_classes = detect_from_classes(snapshot_text, sigs)

    merged = {**from_classes, **from_urls}
    for name, info in from_classes.items():
        if name in from_urls:
            merged[name]["sources"].extend(from_classes[name]["sources"])

    print(json.dumps(merged, indent=2))


if __name__ == "__main__":
    main()
