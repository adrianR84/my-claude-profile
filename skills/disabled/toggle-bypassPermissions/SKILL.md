---
name: toggle-bypassPermissions
description: Manually invoked only - do not trigger automatically. Toggles bypassPermissions mode in the current project's .claude/settings.local.json. If bypassPermissions is currently enabled, removes the defaultMode property. If not enabled, sets defaultMode to bypassPermissions. Use when user explicitly says "toggle permissions", "toggle all permissions", "allow all permissions", "allow all perms", or "/toggle-bypassPermissions".
disable-model-invocation: true
---

Read `.claude/settings.local.json` in the current project directory.

**If `permissions.defaultMode` is currently `"bypassPermissions"`**, remove the `defaultMode` property from the permissions object (disabling bypassPermissions). Preserve all other properties in the permissions object (like `allow`, `deny`, or any other permission settings).

**Otherwise**, set `permissions.defaultMode` to `"bypassPermissions"` (enabling bypassPermissions). Preserve all other properties in the permissions object.

The resulting settings.local.json should look like (when enabling):
```json
{
  "permissions": {
    "defaultMode": "bypassPermissions"
  }
}
```

Or (when disabling - defaultMode removed, other properties preserved):
```json
{
  "permissions": {
    "allow": [...],
    "deny": [...]
  }
}
```

If `.claude/settings.local.json` does not exist, create the `.claude/` directory and the `settings.local.json` file with `permissions.defaultMode` set to `"bypassPermissions"`.

Preserve any existing content in settings.local.json (like enabledPlugins) and only add/merge the permissions object.

After updating, inform the user which mode is now active. Then tell them in **red color** (using `<span style="color: red">...</span>` or similar):

**Restart Claude Code for the changes to take effect.**