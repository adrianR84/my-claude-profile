#!/usr/bin/env node
/**
 * UserPromptSubmit hook: blocks prompts when mmx API quota is low.
 *
 * Prerequisites:
 *   1. npm install -g mmx-cli
 *   2. mmx auth login --api-key sk-xxxxx
 *
 * Install via settings.json:
 *   "hooks": {
 *     "UserPromptSubmit": [{
 *       "hooks": [{ "type": "command", "command": "node ~/.claude/hooks/mmx-quota-block.js" }]
 *     }]
 *   }
 */

const { spawn } = require('child_process');
const fs = require('fs');
const path = require('path');

const LOG_FILE = path.join(process.env.HOME, '.claude', 'hooks-logs', 'mmx-quota-block.jsonl');
const THRESHOLD = 10; // block when API Left drops below 10%

function log(entry) {
  try {
    const dir = path.dirname(LOG_FILE);
    if (!fs.existsSync(dir)) fs.mkdirSync(dir, { recursive: true });
    fs.appendFileSync(LOG_FILE, JSON.stringify({ ts: new Date().toISOString(), ...entry }) + '\n');
  } catch {}
}

function execCommand(cmd, args) {
  return new Promise((resolve, reject) => {
    const child = spawn('bash', ['-c', cmd + ' ' + args.join(' ')], { timeout: 8 });
    let stdout = '', stderr = '';
    child.stdout.on('data', (d) => { stdout += d; });
    child.stderr.on('data', (d) => { stderr += d; });
    child.on('close', (code) => {
      if (code === 0) resolve(stdout.trim());
      else reject(new Error(stderr.trim() || 'exit ' + code));
    });
    child.on('error', reject);
  });
}

function getApiLeftSync() {
  try {
    const child = spawn('bash', ['-c', 'mmx quota'], { timeout: 8000 });
    let stdout = '';
    child.stdout.on('data', (d) => { stdout += d; });
    let stderr = '';
    child.stderr.on('data', (d) => { stderr += d; });
    return new Promise((resolve) => {
      child.on('close', (code) => {
        if (code === 0) {
          try {
            const data = JSON.parse(stdout.trim());
            const g = data.model_remains.find(m => m.model_name === 'general');
            resolve(g ? g.current_interval_remaining_percent : null);
          } catch { resolve(null); }
        } else { resolve(null); }
      });
    });
  } catch { return Promise.resolve(null); }
}

function getResetTimeSync() {
  try {
    const child = spawn('bash', ['-c', 'mmx quota'], { timeout: 8000 });
    let stdout = '';
    child.stdout.on('data', (d) => { stdout += d; });
    return new Promise((resolve) => {
      child.on('close', (code) => {
        if (code === 0) {
          try {
            const data = JSON.parse(stdout.trim());
            const g = data.model_remains.find(m => m.model_name === 'general');
            if (!g) { resolve(null); return; }
            const ms = g.remains_time || 0;
            const h = Math.floor(ms / 3600000);
            const m = Math.round(ms % 3600000 / 60000);
            resolve(h + 'h:' + (m < 10 ? '0' : '') + m + 'm');
          } catch { resolve(null); }
        } else { resolve(null); }
      });
    });
  } catch { return Promise.resolve(null); }
}

// Read stdin via file descriptor 0 (works on Windows too)
let input = '';
try {
  const buf = Buffer.alloc(8192);
  const bytesRead = fs.readSync(0, buf, 0, buf.length, null);
  if (bytesRead > 0) input = buf.toString('utf8', 0, bytesRead);
} catch (e) {
  // fallback
}

if (!input.trim()) {
  console.log('{}');
  process.exit(0);
}

let data;
try {
  data = JSON.parse(input);
} catch (e) {
  console.log('{}');
  process.exit(0);
}

const prompt = data.user_prompt || data.prompt || '';

getApiLeftSync().then((apiLeft) => {
  log({ event: 'hook_called', prompt: prompt.substring(0, 50), apiLeft });

  if (apiLeft === null) {
    log({ event: 'quota_check_failed', allow: true });
    console.log('{}');
    process.exit(0);
    return;
  }

  if (apiLeft < THRESHOLD) {
    getResetTimeSync().then((reset) => {
      const resetStr = reset ? ' Reset in ' + reset + '.' : '';
      log({ event: 'blocked', apiLeft, threshold: THRESHOLD, reset });
      console.log(JSON.stringify({
        decision: 'block',
        reason: 'MMX API quota at ' + apiLeft + '% (threshold: ' + THRESHOLD + '%).' + resetStr + ' Add more credits or wait for reset.'
      }));
      process.exit(0);
    });
    return;
  }

  log({ event: 'allowed', apiLeft, threshold: THRESHOLD });
  console.log('{}');
  process.exit(0);
}).catch((e) => {
  log({ event: 'error', message: e.message });
  console.log('{}');
  process.exit(0);
});
