#!/usr/bin/env node
/**
 * sanitize-json.js - Remove specified keys from a JSON file
 * Usage: node sanitize-json.js <file> <key1> [key2] [...]
 * Reads JSON from file, removes specified top-level keys, writes back.
 * No external dependencies - uses built-in Node.js modules only.
 */

const fs = require('fs');
const path = require('path');

const filePath = process.argv[2];
const keysToRemove = process.argv.slice(3);

if (!filePath || keysToRemove.length === 0) {
  console.error(`Usage: node sanitize-json.js <file> <key1> [key2] [...]\nExample: node sanitize-json.js installed_plugins.json installPath`);
  process.exit(1);
}

if (!fs.existsSync(filePath)) {
  console.error(`File not found: ${filePath}`);
  process.exit(1);
}

try {
  const content = fs.readFileSync(filePath, 'utf8');
  const json = JSON.parse(content);

  let modified = false;
  for (const key of keysToRemove) {
    if (key in json) {
      delete json[key];
      modified = true;
    }
  }

  if (modified) {
    const dir = path.dirname(filePath);
    if (!fs.existsSync(dir)) {
      fs.mkdirSync(dir, { recursive: true });
    }
    fs.writeFileSync(filePath, JSON.stringify(json, null, 2) + '\n', 'utf8');
    console.log(`Sanitized: ${filePath} (removed: ${keysToRemove.join(', ')})`);
  } else {
    console.log(`No changes: ${filePath}`);
  }
} catch (err) {
  console.error(`Error processing ${filePath}: ${err.message}`);
  process.exit(1);
}
