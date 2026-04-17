#!/usr/bin/env node
/**
 * sanitize-json.js — Cross-platform path converter for Claude plugin JSON.
 *
 * ============================================================================
 * PURPOSE
 * ============================================================================
 * When you export (backup) your Claude config, absolute paths like:
 *   C:\Users\you\.claude\plugins\cache\superpowers\5.0.7
 * are converted to portable relative paths:
 *   plugins/cache/superpowers/5.0.7
 *
 * When you import (restore), those relative paths are converted back to
 * absolute paths for the current machine:
 *   C:\Users\you\.claude\plugins\cache\superpowers\5.0.7   (Windows)
 *   /home/you/.claude/plugins/cache/superpowers/5.0.7       (Linux/Mac)
 *
 * This makes your backup portable across different machines and OSes.
 *
 * ============================================================================
 * USAGE
 * ============================================================================
 *   node sanitize-json.js export <file> [--config-dir <path>]
 *   node sanitize-json.js import <file> [--config-dir <path>]
 *
 * Arguments:
 *   mode      - "export" to convert absolute → relative, "import" for reverse
 *   file      - Path to the JSON file to process (installed_plugins.json or
 *               known_marketplaces.json)
 *   --config-dir - (optional) Override the Claude config directory path.
 *                  Defaults to $CLAUDE_CONFIG_DIR or ~/.claude
 *
 * Environment:
 *   CLAUDE_CONFIG_DIR - If set, used as the ~/.claude base path. This is
 *                       useful when Claude uses a custom config directory.
 *
 * ============================================================================
 * HOW IT WORKS
 * ============================================================================
 *
 * EXPORT mode:
 *   1. Read the JSON file
 *   2. Find all `installPath` and `installLocation` fields (recursively)
 *   3. For each path:
 *      - Normalize backslashes to forward slashes (Windows → cross-platform)
 *      - Strip the ~/.claude/ prefix
 *      - Store only the relative portion
 *   4. Write the JSON back with relative paths
 *
 *   Example:
 *     "C:\Users\adria\.claude\plugins\cache\foo\1.0.0"
 *     becomes:
 *     "plugins/cache/foo/1.0.0"
 *
 * IMPORT mode:
 *   1. Read the JSON file (which has relative paths from backup)
 *   2. Find all `installPath` and `installLocation` fields
 *   3. For each path:
 *      - Prepend the Claude config directory (e.g., ~/.claude/)
 *      - Use OS-native path separators (path.join handles this)
 *   4. Write the JSON back with absolute paths
 *
 *   Example:
 *     "plugins/cache/foo/1.0.0"
 *     becomes:
 *     "C:\Users\adria\.claude\plugins\cache\foo\1.0.0"   (Windows)
 *     or
 *     "/home/adria/.claude/plugins/cache/foo/1.0.0"       (Linux/Mac)
 *
 * ============================================================================
 * JSON STRUCTURES HANDLED
 * ============================================================================
 *
 * installed_plugins.json (flat map):
 *   {
 *     "claude-plugins-official": {
 *       "installLocation": "C:\\Users\\...\\marketplaces\\claude-plugins-official"
 *     }
 *   }
 *
 * known_marketplaces.json (nested):
 *   {
 *     "version": 2,
 *     "plugins": {
 *       "superpowers@claude-plugins-official": [
 *         {
 *           "installPath": "C:\\Users\\...\\cache\\claude-plugins-official\\superpowers\\5.0.7"
 *         }
 *       ]
 *     }
 *   }
 *
 * Both structures are handled recursively — the walker descends into arrays
 * and nested objects to find all instances of installPath/installLocation.
 *
 * ============================================================================
 * CROSS-PLATFORM NOTES
 * ============================================================================
 *
 * - Backup files always use FORWARD SLASHES (/), never backslashes (\).
 *   This ensures the backup works on any OS, even if created on Windows.
 *
 * - On import, path.join() automatically uses the correct separator for
 *   the current OS (backslash on Windows, forward slash on Unix).
 *
 * - If a path doesn't start with the Claude config directory (e.g., it's
 *   already relative, or points to a non-Claude location), it's left unchanged.
 *   This prevents accidental modifications to third-party paths.
 */

const fs   = require('fs');
const path = require('path');
const os   = require('os');

// ─── Path utilities ──────────────────────────────────────────────────────────

/**
 * normalizePathSep — Convert all backslashes to forward slashes.
 *
 * Windows paths often contain backslashes: C:\Users\me\.claude\plugins
 * Unix paths use forward slashes:     /home/me/.claude/plugins
 *
 * For backup portability, we always store paths with forward slashes,
 * regardless of the source OS.
 *
 * @param {string} p - Path string that may contain backslashes
 * @returns {string} - Path with all backslashes replaced by forward slashes
 */
function normalizePathSep(p) {
  return p.replace(/\\/g, '/');
}

/**
 * toRelativePath — Convert an absolute Claude path to a relative path.
 *
 * Strips the Claude config directory prefix and normalizes to forward slashes.
 * Used during EXPORT to create portable backup files.
 *
 * Example (Windows):
 *   Input:  'C:\Users\adria\.claude\plugins\cache\foo\1.0.0'
 *   Output: 'plugins/cache/foo/1.0.0'
 *
 * Example (Linux/Mac):
 *   Input:  '/home/adria/.claude/plugins/cache/foo/1.0.0'
 *   Output: 'plugins/cache/foo/1.0.0'
 *
 * @param {string} absPath - Absolute path to convert (e.g., 'C:\Users\me\.claude\...')
 * @param {string} claudeDir - The Claude config directory base (e.g., '/home/me/.claude')
 * @returns {string} - Relative path suitable for backup, or unchanged if not under claudeDir
 */
function toRelativePath(absPath, claudeDir) {
  // If path doesn't start with claudeDir, leave it unchanged
  if (!isExportablePath(absPath, claudeDir)) {
    return absPath;
  }

  // Normalize both paths to use forward slashes for consistent comparison
  const normalised = normalizePathSep(absPath);
  const base = normalizePathSep(claudeDir);

  // Strip the base directory prefix + the trailing slash
  // e.g., 'C:/Users/adria/.claude/plugins/cache/foo'
  //       - base = 'C:/Users/adria/.claude'
  //       - result = 'plugins/cache/foo'
  if (normalised.startsWith(base + '/')) {
    return normalised.slice(base.length + 1);
  }

  // Edge case: if the path IS the base directory itself (unlikely)
  if (normalised === base) {
    return '';
  }

  // Fallback: return unchanged if something unexpected happened
  return absPath;
}

/**
 * toAbsolutePath — Convert a relative Claude path to an absolute path.
 *
 * Prepends the Claude config directory and uses OS-native separators.
 * Used during IMPORT to restore paths on the current machine.
 *
 * Example (Windows):
 *   Input:  'plugins/cache/foo/1.0.0'
 *   Output: 'C:\Users\adria\.claude\plugins\cache\foo\1.0.0'
 *
 * Example (Linux/Mac):
 *   Input:  'plugins/cache/foo/1.0.0'
 *   Output: '/home/adria/.claude/plugins/cache/foo/1.0.0'
 *
 * @param {string} relPath - Relative path from backup (e.g., 'plugins/cache/foo')
 * @param {string} claudeDir - The Claude config directory (e.g., 'C:\Users\adria\.claude')
 * @returns {string} - Absolute path for the current OS, or unchanged if not importable
 */
function toAbsolutePath(relPath, claudeDir) {
  // Only process paths that look like relative plugin paths
  if (!isImportablePath(relPath)) {
    return relPath;
  }

  // path.join() automatically uses the correct separator for this OS
  // and handles any path normalization needed
  const result = path.join(claudeDir, ...relPath.split('/'));
  return result;
}

/**
 * isExportablePath — Check if an absolute path is under the Claude directory.
 *
 * Used to determine if a path should be converted during export.
 * Returns false for:
 *   - Empty or non-string values
 *   - Paths that don't start with the Claude config directory
 *   - Already-relative paths
 *
 * @param {string} absPath - The path to check
 * @param {string} claudeDir - The Claude config directory base
 * @returns {boolean} - true if the path should be exported (converted to relative)
 */
function isExportablePath(absPath, claudeDir) {
  // Must be a non-empty string
  if (typeof absPath !== 'string' || absPath.length === 0) {
    return false;
  }

  // Normalize the Claude directory for consistent comparison
  const base = normalizePathSep(claudeDir);

  // Check if the path, when normalized, starts with the Claude directory
  // The path must be inside the Claude directory (hence the trailing '/' check)
  return normalizePathSep(absPath).startsWith(base + '/');
}

/**
 * isImportablePath — Check if a path looks like a relative plugin path.
 *
 * Used to determine if a path should be converted during import.
 * Returns false for:
 *   - Empty or non-string values
 *   - Paths that don't start with 'plugins/' (our convention for relative paths)
 *
 * This prevents accidentally converting paths that happen to contain
 * forward slashes but aren't actually relative Claude paths.
 *
 * @param {string} relPath - The path to check
 * @returns {boolean} - true if the path should be imported (converted to absolute)
 */
function isImportablePath(relPath) {
  // Must be a non-empty string
  if (typeof relPath !== 'string' || relPath.length === 0) {
    return false;
  }

  // Must start with 'plugins/' to be considered a relative Claude path
  // Also allow the bare 'plugins' directory itself
  return relPath.startsWith('plugins/') || relPath === 'plugins';
}

// ─── Config dir resolution ──────────────────────────────────────────────────

/**
 * getClaudeDir — Resolve the Claude config directory path.
 *
 * The Claude config directory is where your .claude folder lives.
 * This is typically ~/.claude but can be customized via CLAUDE_CONFIG_DIR.
 *
 * Resolution order (first non-empty wins):
 *   1. CLI --config-dir argument
 *   2. CLAUDE_CONFIG_DIR environment variable
 *   3. $HOME/.claude (for Unix-like systems)
 *   4. os.homedir()/.claude (fallback)
 *
 * The result has any trailing slashes removed to prevent double-slash issues.
 *
 * @param {string|undefined} configDirArg - CLI --config-dir argument (optional)
 * @returns {string} - Resolved Claude config directory path
 */
function getClaudeDir(configDirArg) {
  const envConfigDir = process.env.CLAUDE_CONFIG_DIR;
  const envHome = process.env.HOME;
  const sysHome = os.homedir();

  // Priority order: explicit arg > env var > HOME fallback > system home fallback
  const raw = configDirArg || envConfigDir || envHome + '/.claude' || sysHome + '/.claude';

  // Remove trailing slashes for consistent handling
  return raw.replace(/[\\/]+$/, '');
}

// ─── JSON walker ─────────────────────────────────────────────────────────────

/**
 * Set of JSON keys that contain paths we want to convert.
 * Includes common variations and aliases.
 */
const TARGET_KEYS = new Set([
  'installPath',      // known_marketplaces.json uses this
  'installLocation',  // installed_plugins.json uses this
  'install_path',     // snake_case variant (just in case)
  'install_location'  // snake_case variant (just in case)
]);

/**
 * walk — Recursively walk through a JSON object and convert paths.
 *
 * This function traverses the entire JSON structure, finding all instances
 * of installPath and installLocation (at any nesting level) and converts
 * them based on the mode:
 *   - 'export': absolute → relative
 *   - 'import': relative → absolute
 *
 * Handles:
 *   - Nested objects (recurses into values)
 *   - Arrays (recurses into each element)
 *   - Primitives other than strings (ignored)
 *   - null values (ignored)
 *
 * @param {*} node - Current JSON node (object, array, or primitive)
 * @param {string} mode - 'export' or 'import'
 * @param {string} claudeDir - The Claude config directory
 * @returns {boolean} - true if this node or any descendant was modified
 */
function walk(node, mode, claudeDir) {
  // Base case: null or non-object (primitive) — nothing to do
  if (node === null || typeof node !== 'object') {
    return false;
  }

  // Handle arrays — recurse into each element
  if (Array.isArray(node)) {
    let changed = false;
    for (let i = 0; i < node.length; i++) {
      // If any element changed, mark the whole array as changed
      if (walk(node[i], mode, claudeDir)) {
        changed = true;
      }
    }
    return changed;
  }

  // Handle objects — check each key
  let changed = false;
  for (const key of Object.keys(node)) {
    const val = node[key];

    // If this key is one of our target path fields AND the value is a string,
    // convert it based on the mode
    if (typeof val === 'string' && TARGET_KEYS.has(key)) {
      const next = mode === 'export'
        ? toRelativePath(val, claudeDir)   // absolute → relative
        : toAbsolutePath(val, claudeDir);  // relative → absolute

      // Only update if the value actually changed
      if (next !== val) {
        node[key] = next;
        changed = true;
      }
    } else {
      // Recurse into this value (might contain nested objects/arrays)
      if (walk(val, mode, claudeDir)) {
        changed = true;
      }
    }
  }

  return changed;
}

// ─── CLI ──────────────────────────────────────────────────────────────────────

/**
 * main — CLI entry point.
 *
 * Parses arguments, reads/writes JSON files, and calls the walker.
 */
function main() {
  const args = process.argv.slice(2);

  // Parse --config-dir <path> argument (precedes mode and file)
  let configDirArg = undefined;
  let cleanArgs = [];

  for (let i = 0; i < args.length; i++) {
    if (args[i] === '--config-dir' && i + 1 < args.length) {
      // Found --config-dir, take the next argument as its value
      configDirArg = args[++i];
    } else {
      // Keep all other arguments
      cleanArgs.push(args[i]);
    }
  }

  // After parsing, cleanArgs should have: [mode, filePath]
  const [mode, filePath] = cleanArgs;

  // Validate arguments
  if (!mode || !filePath) {
    console.error(
      'Usage: node sanitize-json.js <export|import> <file> [--config-dir <path>]\n' +
      '  export   Convert absolute paths to relative (for backup)\n' +
      '  import   Convert relative paths to absolute (for restore)\n' +
      '  --config-dir  Path to .claude dir (defaults to $CLAUDE_CONFIG_DIR or ~/.claude)'
    );
    process.exit(1);
  }

  // Validate mode
  if (mode !== 'export' && mode !== 'import') {
    console.error(`Unknown mode "${mode}". Use "export" or "import".`);
    process.exit(1);
  }

  // Validate file exists
  if (!fs.existsSync(filePath)) {
    console.error(`File not found: ${filePath}`);
    process.exit(1);
  }

  // Resolve the Claude config directory
  const claudeDir = getClaudeDir(configDirArg);

  // Read and parse the JSON file
  let json;
  try {
    json = JSON.parse(fs.readFileSync(filePath, 'utf8'));
  } catch (err) {
    console.error(`Failed to parse JSON in ${filePath}: ${err.message}`);
    process.exit(1);
  }

  // Walk the JSON and convert paths
  const modified = walk(json, mode, claudeDir);

  // If nothing changed, we're done
  if (!modified) {
    console.log(`No changes: ${filePath}`);
    return;
  }

  // Ensure the directory exists (should already exist, but be safe)
  const dir = path.dirname(filePath);
  if (!fs.existsSync(dir)) {
    fs.mkdirSync(dir, { recursive: true });
  }

  // Write the modified JSON back with pretty formatting
  fs.writeFileSync(filePath, JSON.stringify(json, null, 2) + '\n', 'utf8');
  console.log(`Sanitized (${mode}): ${filePath}`);
}

// Run the CLI
main();
