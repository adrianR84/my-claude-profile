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
const CACHE_FILE = path.join(process.env.HOME, '.claude', 'hooks-logs', 'mmx-quota-cache.json');
const THRESHOLD = 10; // block when API Left drops below 10%
const CACHE_TTL = 60; // cache quota for 60 seconds
const LOG_ENABLED = false; // set to true to enable logging

function log(entry) {
  if (!LOG_ENABLED) return;
  try {
    const dir = path.dirname(LOG_FILE);
    if (!fs.existsSync(dir)) fs.mkdirSync(dir, { recursive: true });
    fs.appendFileSync(LOG_FILE, JSON.stringify({ ts: new Date().toISOString(), ...entry }) + '\n');
  } catch {}
}

function readCache() {
  try {
    const raw = fs.readFileSync(CACHE_FILE, 'utf8');
    const cache = JSON.parse(raw);
    if ((Date.now() - cache.ts) < CACHE_TTL * 1000) return cache;
  } catch {}
  return null;
}

function writeCache(quota) {
  try {
    const dir = path.dirname(CACHE_FILE);
    if (!fs.existsSync(dir)) fs.mkdirSync(dir, { recursive: true });
    fs.writeFileSync(CACHE_FILE, JSON.stringify(quota));
  } catch {}
}

function getQuota() {
  return new Promise((resolve) => {
    const cached = readCache();
    if (cached) { resolve({ ...cached, cached: true }); return; }

    try {
      const child = spawn('bash', ['-c', 'mmx quota'], { timeout: 8000 });
      let stdout = '';
      child.stdout.on('data', (d) => { stdout += d; });
      child.on('close', (code) => {
        if (code === 0) {
          try {
            const data = JSON.parse(stdout.trim());
            const g = data.model_remains.find(m => m.model_name === 'general');
            if (g) {
              const ms = g.remains_time || 0;
              const h = Math.floor(ms / 3600000);
              const m = Math.round(ms % 3600000 / 60000);
              const quota = {
                apiLeft: g.current_interval_remaining_percent,
                reset: h + 'h:' + (m < 10 ? '0' : '') + m + 'm',
                ts: Date.now()
              };
              writeCache(quota);
              resolve(quota);
              return;
            }
          } catch {}
        }
        resolve(null);
      });
    } catch { resolve(null); }
  });
}

// Read stdin via fd 0 (Windows-compatible)
let input = '';
try {
  const buf = Buffer.alloc(8192);
  const r = fs.readSync(0, buf, 0, buf.length, null);
  if (r > 0) input = buf.toString('utf8', 0, r);
} catch (e) {}

if (!input.trim()) { console.log('{}'); process.exit(0); }

let data;
try { data = JSON.parse(input); } catch (e) { console.log('{}'); process.exit(0); }

const prompt = data.user_prompt || data.prompt || '';

getQuota().then((quota) => {
  const apiLeft = quota ? quota.apiLeft : null;
  log({ event: 'hook_called', prompt: prompt.substring(0, 50), apiLeft, cached: quota.cached || false });

  if (apiLeft === null) {
    log({ event: 'quota_check_failed', allow: true });
    console.log('{}');
    process.exit(0);
    return;
  }

  if (apiLeft < THRESHOLD) {
    const resetStr = quota.reset ? ' Reset in ' + quota.reset + '.' : '';
    log({ event: 'blocked', apiLeft, threshold: THRESHOLD, reset: quota.reset });
    console.log(JSON.stringify({
      decision: 'block',
      reason: 'MMX API quota at ' + apiLeft + '% (threshold: ' + THRESHOLD + '%).' + resetStr + ' Add more credits or wait for reset.'
    }));
    process.exit(0);
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
