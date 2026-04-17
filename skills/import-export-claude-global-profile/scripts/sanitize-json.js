#!/usr/bin/env node
/**
 * sanitize-json.js — Cross-platform path converter for Claude plugin JSON.
 *
 * Modes:
 *   export  : strip ~/.claude/ prefix, normalise to forward slashes
 *   import  : prepend ~/.claude/ base, use OS-native separators
 *
 * Usage:
 *   node sanitize-json.js export <file> [--config-dir <path>]
 *   node sanitize-json.js import <file> [--config-dir <path>]
 *
 * Keys processed: installPath, installLocation (and their aliases).
 *
 * Environment:
 *   CLAUDE_CONFIG_DIR  - if set, used as the ~/.claude/ base path directly
 */

const fs   = require('fs');
const path = require('path');
const os   = require('os');

// ─── Path utilities ──────────────────────────────────────────────────────────

/** Replace all backslashes with forward slashes. */
function normalizePathSep(p) {
  return p.replace(/\\/g, '/');
}

/**
 * Convert an absolute ~/.claude/ path to a relative, forward-slash path.
 */
function toRelativePath(absPath, claudeDir) {
  if (!isExportablePath(absPath, claudeDir)) {
    return absPath;
  }
  const normalised = normalizePathSep(absPath);
  const base = normalizePathSep(claudeDir);
  if (normalised.startsWith(base + '/')) {
    return normalised.slice(base.length + 1);
  }
  return absPath;
}

/**
 * Convert a relative, forward-slash path to an absolute ~/.claude/ path
 * using OS-native separators.
 */
function toAbsolutePath(relPath, claudeDir) {
  if (!isImportablePath(relPath)) {
    return relPath;
  }
  const result = path.join(claudeDir, ...relPath.split('/'));
  return result;
}

/** True when absPath starts with the normalised claudeDir base. */
function isExportablePath(absPath, claudeDir) {
  if (typeof absPath !== 'string' || absPath.length === 0) return false;
  const base = normalizePathSep(claudeDir);
  return normalizePathSep(absPath).startsWith(base + '/');
}

/** True when relPath looks like a non-empty relative plugin path. */
function isImportablePath(relPath) {
  if (typeof relPath !== 'string' || relPath.length === 0) return false;
  return relPath.startsWith('plugins/') || relPath === 'plugins';
}

// ─── Config dir resolution ──────────────────────────────────────────────────

/**
 * Resolve the Claude config directory (~/.claude or $CLAUDE_CONFIG_DIR).
 * Priority: CLI --config-dir > CLAUDE_CONFIG_DIR env > HOME/.claude > os.homedir()/.claude
 */
function getClaudeDir(configDirArg) {
  const envConfigDir = process.env.CLAUDE_CONFIG_DIR;
  const envHome = process.env.HOME;
  const sysHome = os.homedir();

  const raw = configDirArg || envConfigDir || envHome + '/.claude' || sysHome + '/.claude';
  return raw.replace(/[\\/]+$/, '');
}

// ─── JSON walker ─────────────────────────────────────────────────────────────

const TARGET_KEYS = new Set(['installPath', 'installLocation', 'install_path', 'install_location']);

function walk(node, mode, claudeDir) {
  if (node === null || typeof node !== 'object') return false;

  if (Array.isArray(node)) {
    let changed = false;
    for (let i = 0; i < node.length; i++) {
      if (walk(node[i], mode, claudeDir)) changed = true;
    }
    return changed;
  }

  let changed = false;
  for (const key of Object.keys(node)) {
    const val = node[key];
    if (typeof val === 'string' && TARGET_KEYS.has(key)) {
      const next = mode === 'export' ? toRelativePath(val, claudeDir)
                                    : toAbsolutePath(val, claudeDir);
      if (next !== val) {
        node[key] = next;
        changed  = true;
      }
    } else {
      if (walk(val, mode, claudeDir)) changed = true;
    }
  }
  return changed;
}

// ─── CLI ──────────────────────────────────────────────────────────────────────

function main() {
  const args = process.argv.slice(2);

  let configDirArg = undefined;
  let cleanArgs = [];
  for (let i = 0; i < args.length; i++) {
    if (args[i] === '--config-dir' && i + 1 < args.length) {
      configDirArg = args[++i];
    } else {
      cleanArgs.push(args[i]);
    }
  }

  const [mode, filePath] = cleanArgs;

  if (!mode || !filePath) {
    console.error(
      'Usage: node sanitize-json.js <export|import> <file> [--config-dir <path>]\n' +
      '  --config-dir  path to .claude dir (defaults to $CLAUDE_CONFIG_DIR or ~/.claude)'
    );
    process.exit(1);
  }

  if (mode !== 'export' && mode !== 'import') {
    console.error(`Unknown mode "${mode}". Use "export" or "import".`);
    process.exit(1);
  }

  if (!fs.existsSync(filePath)) {
    console.error(`File not found: ${filePath}`);
    process.exit(1);
  }

  const claudeDir = getClaudeDir(configDirArg);
  console.error(`Using config dir: ${claudeDir}`);

  let json;
  try {
    json = JSON.parse(fs.readFileSync(filePath, 'utf8'));
  } catch (err) {
    console.error(`Failed to parse JSON in ${filePath}: ${err.message}`);
    process.exit(1);
  }

  const modified = walk(json, mode, claudeDir);

  if (!modified) {
    console.log(`No changes: ${filePath}`);
    return;
  }

  const dir = path.dirname(filePath);
  if (!fs.existsSync(dir)) {
    fs.mkdirSync(dir, { recursive: true });
  }

  fs.writeFileSync(filePath, JSON.stringify(json, null, 2) + '\n', 'utf8');
  console.log(`Sanitized (${mode}): ${filePath}`);
}

main();
