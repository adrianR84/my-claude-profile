---
name: bump-plugin-versions
description: |
  Bumps version in .claude-plugin/plugin.json and .claude-plugin/marketplace.json. Use whenever the user mentions bumping, incrementing, or updating a plugin version. Example: "bump the version" or "update plugin version to 1.0.1"
---

# Bump Plugin Versions

Increments patch version in plugin metadata files, or sets a specific version if provided.

## Files to update

Both files are in `.claude-plugin/` under the current working directory:
- `plugin.json` — update/add `version` at root level
- `marketplace.json` — update `version` for the matching plugin in the `plugins` array

## How to bump

**Patch increment (default):** `1.0.0` → `1.0.1`, etc. Set to `1.0.0` if no version exists.

## Version handling

**Single-plugin marketplace.json** (1 plugin in `plugins[]`): Both `plugin.json` and the marketplace plugin entry use the **same** version. One version bump applies to both files.

**Multi-plugin marketplace.json**: Each plugin in `plugins[]` bumps its own version independently.

**Specific version:** If the user specifies a version (e.g., "bump to 2.0.0"), all files use that exact version.

## Steps

1. **Read both files** to get current versions:
   - Read `.claude-plugin/plugin.json`
   - Read `.claude-plugin/marketplace.json`

2. **Determine the target version:**
   - If user gave a specific version → use it for all
   - **Single-plugin marketplace.json**: Read version from the plugin entry in marketplace.json, increment patch
   - **Multi-plugin marketplace.json**: Each plugin bumps its own version individually

3. **Update plugin.json:**
   - Single-plugin case: set version to the incremented marketplace plugin version
   - Multi-plugin case: set version to the target (user-specified or incremented from plugin.json's own version)

4. **Update marketplace.json:**
   - Parse the `plugins` array
   - For **each** plugin entry:
     - Read its current `version`, or start at `1.0.0` if missing
     - Increment patch version individually (each plugin bumps its own version)
   - Replace each plugin's `version` with its individually incremented value

## Version increment logic (per-plugin)

Each plugin in `marketplace.json.plugins[]` maintains its own version. Increment each individually:

```javascript
function incrementPatch(version) {
  const parts = version.split('.').map(Number);
  parts[2] += 1;
  return parts.join('.');
}
```

If a plugin has no version, start at `1.0.0`.

## Success criteria

- plugin.json version matches incremented version
- Each plugin in marketplace.json.plugins[] has its individually incremented version
- Exit code 0 on success, 1 if files not found

## Summary output

After updating, print a table summarizing all changes:

```
Plugin                  │ Before │ After
────────────────────────┼────────┼──────
rss-aggregator          │ 1.0.2  │ 1.0.3
another-plugin          │ 2.1.0  │ 2.1.1
```

Use the `name` field from each plugin entry as the plugin label.
