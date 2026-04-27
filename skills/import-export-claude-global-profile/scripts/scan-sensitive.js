#!/usr/bin/env node
/**
 * scan-sensitive.js - Detects and optionally redacts API keys and sensitive data in settings.json.
 * 
 * Usage: 
 *   node scan-sensitive.js detect <settings.json path>          - Just detect (exit 0=clean, 1=sensitive found)
 *   node scan-sensitive.js redact <settings.json path> --with <placeholder>  - Redact in place
 * 
 * Exit codes: 0=success (or clean for detect), 1=sensitive found (detect only), 2=file error
 */

const fs = require('fs');

// Patterns for sensitive data
const PATTERNS = [
  { name: 'OpenAI API Key', regex: /sk-[A-Za-z0-9_-]{20,}/ },
  { name: 'Anthropic API Key', regex: /sk-ant-[A-Za-z0-9_-]{20,}/ },
  { name: 'GitHub Token', regex: /(?:ghp|gho|ghu|ghs|ghr)_[A-Za-z0-9_]{36,}/ },
  { name: 'AWS Access Key', regex: /AKIA[A-Z0-9]{16}/ },
  { name: 'Stripe Key', regex: /sk_live_[A-Za-z0-9]{24,}/ },
  { name: 'Slack Token', regex: /xox[baprs]-[A-Za-z0-9-]+/ },
  { name: 'Discord Token', regex: /[A-Za-z\d]{24}\.[A-Za-z\d]{6}\.[A-Za-z\d_-]{27,}/ },
  { name: 'JWT Token', regex: /eyJ[A-Za-z0-9_-]*\.eyJ[A-Za-z0-9_-]*\.[A-Za-z0-9_-]*/ },
  { name: 'Private Key', regex: /-----BEGIN\s+(?:RSA\s+|EC\s+|DSA\s+|OPENSSH\s+)?PRIVATE\s+KEY-----/ },
  { name: 'Webhook Secret', regex: /whsec_[A-Za-z0-9_-]{24,}/ },
];

const SENSITIVE_KEYS = new Set([
  'api_key','apikey','api-key','secret','password','token','access_token',
  'private_key','aws_access_key','aws_secret_key','stripe_key','slack_token',
  'discord_token','github_token','webhook_secret','encryption_key'
]);

function mask(v) {
  return v.length <= 8 ? '*'.repeat(v.length) : v.slice(0,4) + '*'.repeat(Math.min(v.length-8,20)) + v.slice(-4);
}

function findSensitive(node, path = '', findings = []) {
  if (node === null || typeof node !== 'object') return findings;
  
  if (Array.isArray(node)) {
    node.forEach((item, i) => findSensitive(item, `${path}[${i}]`, findings));
    return findings;
  }
  
  for (const key of Object.keys(node)) {
    const val = node[key];
    const cur = path ? `${path}.${key}` : key;
    
    if (typeof val === 'string' && val.trim()) {
      if (SENSITIVE_KEYS.has(key.toLowerCase())) {
        findings.push({ path: cur, key, value: val, isKey: true });
      }
      for (const p of PATTERNS) {
        if (p.regex.test(val)) {
          findings.push({ path: cur, key, value: val, isPattern: true, patternName: p.name });
        }
      }
    } else if (typeof val === 'object' && val !== null) {
      findSensitive(val, cur, findings);
    }
  }
  return findings;
}

function redact(node, placeholder, path = '', count = [0]) {
  if (node === null || typeof node !== 'object') return count[0];
  
  if (Array.isArray(node)) {
    node.forEach((item, i) => redact(item, placeholder, `${path}[${i}]`, count));
    return count[0];
  }
  
  for (const key of Object.keys(node)) {
    const val = node[key];
    const cur = path ? `${path}.${key}` : key;
    
    if (typeof val === 'string' && val.trim()) {
      let replaced = false;
      let newVal = val;
      
      // Check if key name is sensitive
      if (SENSITIVE_KEYS.has(key.toLowerCase())) {
        newVal = placeholder;
        replaced = true;
      }
      
      // Check patterns
      if (!replaced) {
        for (const p of PATTERNS) {
          if (p.regex.test(newVal)) {
            newVal = placeholder;
            replaced = true;
            break;
          }
        }
      }
      
      if (replaced) {
        node[key] = newVal;
        count[0]++;
      }
    } else if (typeof val === 'object' && val !== null) {
      redact(val, placeholder, cur, count);
    }
  }
  return count[0];
}

const args = process.argv.slice(2);
const command = args[0];

if (command === 'detect') {
  const filePath = args[1];
  if (!filePath) {
    console.error('Usage: node scan-sensitive.js detect <settings.json path>');
    process.exit(2);
  }
  if (!fs.existsSync(filePath)) {
    console.error(`File not found: ${filePath}`);
    process.exit(2);
  }
  let json;
  try {
    json = JSON.parse(fs.readFileSync(filePath, 'utf8'));
  } catch (e) {
    console.error(`JSON parse error: ${e.message}`);
    process.exit(2);
  }
  
  const findings = findSensitive(json);
  
  if (findings.length === 0) {
    console.log('CLEAN: No sensitive data detected');
    process.exit(0);
  }
  
  // Deduplicate by path
  const seen = new Set();
  const unique = findings.filter(f => {
    const k = f.path;
    if (seen.has(k)) return false;
    seen.add(k);
    return true;
  });
  
  console.log('WARNING: Sensitive data detected - NOT recommended for GitHub export');
  console.log('');
  unique.forEach(f => {
    console.log(`[${f.isKey ? 'Sensitive key' : f.patternName}]`);
    console.log(`  Path: ${f.path}`);
    console.log(`  Value: ${mask(f.value)}`);
    console.log('');
  });
  console.log(`${unique.length} item(s) detected`);
  
  process.exit(1);
}
else if (command === 'redact') {
  // Parse: redact <file> --with <placeholder>
  let filePath, placeholder;
  for (let i = 1; i < args.length; i++) {
    if (args[i] === '--with' && i + 1 < args.length) {
      placeholder = args[++i];
    } else if (!filePath) {
      filePath = args[i];
    }
  }
  
  if (!filePath || !placeholder) {
    console.error('Usage: node scan-sensitive.js redact <settings.json path> --with <placeholder>');
    process.exit(2);
  }
  if (!fs.existsSync(filePath)) {
    console.error(`File not found: ${filePath}`);
    process.exit(2);
  }
  
  let json;
  try {
    json = JSON.parse(fs.readFileSync(filePath, 'utf8'));
  } catch (e) {
    console.error(`JSON parse error: ${e.message}`);
    process.exit(2);
  }
  
  const count = redact(json, placeholder);
  
  if (count === 0) {
    console.log('CLEAN: No sensitive data detected, file unchanged');
    process.exit(0);
  }
  
  fs.writeFileSync(filePath, JSON.stringify(json, null, 2) + '\n', 'utf8');
  console.log(`REDACTED: ${count} sensitive value(s) replaced with "${placeholder}"`);
  process.exit(0);
}
else {
  console.error('Usage:');
  console.error('  node scan-sensitive.js detect <settings.json path>');
  console.error('  node scan-sensitive.js redact <settings.json path> --with <placeholder>');
  process.exit(2);
}
