#!/usr/bin/env node
/**
 * Daily AI — Fetch Feeds (Node.js)
 * Fetches the 3 JSON feeds from GitHub only if remote has changed (Etag/Last-Modified).
 * Caches locally; serves from cache if remote unchanged.
 */

import { writeFileSync, readFileSync, existsSync, mkdirSync, statSync } from 'fs';
import { join, dirname } from 'path';
import { fileURLToPath } from 'url';

const __dirname = dirname(fileURLToPath(import.meta.url));

// -- Defaults ----------------------------------------------------------------
const REPO = process.env.DAILY_AI_REPO || 'zarazhangrui/follow-builders';
const BASE = `https://raw.githubusercontent.com/${REPO}/main`;
const X_LIMIT = parseInt(process.env.DAILY_AI_X_LIMIT || '20', 10);
const CACHE_DIR = process.env.DAILY_AI_CACHE_DIR || join(__dirname, '..', 'cache');
const FORCE_REFRESH = process.env.DAILY_AI_FORCE_REFRESH === '1';

// Ensure cache directory exists
mkdirSync(CACHE_DIR, { recursive: true });

// -- Fetch-or-cache helper ----------------------------------------------------
async function fetchOrCache(remoteUrl, cacheFile) {
  const etagFile = cacheFile + '.etag';
  const lmFile = cacheFile + '.lm';

  // HEAD request to get Etag and Last-Modified
  const headRes = await fetch(remoteUrl, { method: 'HEAD' });
  if (!headRes.ok) {
    // Try reading from cache on error
    if (existsSync(cacheFile)) return readFileSync(cacheFile, 'utf8');
    return null;
  }

  const remoteEtag = headRes.headers.get('etag')?.replace(/^"|"$/g, '') || '';
  const remoteLm = headRes.headers.get('last-modified') || '';

  // Check if cached version matches
  if (!FORCE_REFRESH && existsSync(cacheFile) && existsSync(etagFile)) {
    const cachedEtag = readFileSync(etagFile, 'utf8').trim();
    if (remoteEtag && remoteEtag === cachedEtag) {
      return readFileSync(cacheFile, 'utf8');
    }
  }

  if (!FORCE_REFRESH && existsSync(cacheFile) && existsSync(lmFile)) {
    const cachedLm = readFileSync(lmFile, 'utf8').trim();
    if (remoteLm && remoteLm === cachedLm) {
      return readFileSync(cacheFile, 'utf8');
    }
  }

  // Cache miss or changed — fetch fresh
  const contentRes = await fetch(remoteUrl);
  if (!contentRes.ok) {
    if (existsSync(cacheFile)) return readFileSync(cacheFile, 'utf8');
    return null;
  }

  const content = await contentRes.text();
  writeFileSync(cacheFile, content);
  if (remoteEtag) writeFileSync(etagFile, remoteEtag);
  if (remoteLm) writeFileSync(lmFile, remoteLm);

  return content;
}

// -- Main --------------------------------------------------------------------
async function main() {
  // Fetch all 3 feeds concurrently
  const [podcastsRaw, xRaw, blogsRaw] = await Promise.all([
    fetchOrCache(`${BASE}/feed-podcasts.json`, join(CACHE_DIR, 'feed-podcasts.json')),
    fetchOrCache(`${BASE}/feed-x.json`, join(CACHE_DIR, 'feed-x.json')),
    fetchOrCache(`${BASE}/feed-blogs.json`, join(CACHE_DIR, 'feed-blogs.json')),
  ]);

  const podcasts = podcastsRaw ? JSON.parse(podcastsRaw) : null;
  const xFeed = xRaw ? JSON.parse(xRaw) : null;
  const blogs = blogsRaw ? JSON.parse(blogsRaw) : null;

  const pcOk = podcasts?.podcasts ? 1 : 0;
  const xOk = xFeed?.x ? 1 : 0;
  const blOk = blogs?.blogs ? 1 : 0;

  const pcCount = podcasts?.podcasts?.length || 0;
  const xTotal = xFeed?.x ? xFeed.x.reduce((s, u) => s + (u.tweets?.length || 0), 0) : 0;
  const blCount = blogs?.blogs?.length || 0;

  // Top X tweets by engagement
  let topX = [];
  let xShown = 0;
  if (xOk === 1 && xTotal > 0) {
    const scored = [];
    for (const user of xFeed.x) {
      for (const tweet of user.tweets || []) {
        scored.push({
          ...tweet,
          bx_handle: user.handle,
          bx_name: user.name,
          _score: tweet.likes + (tweet.retweets || 0) * 2,
        });
      }
    }
    scored.sort((a, b) => b._score - a._score);
    topX = scored.slice(0, X_LIMIT).map(({ _score, ...t }) => t);
    xShown = topX.length;
  }

  // Trim blog content
  const trimmedBlogs = blOk === 1
    ? { blogs: blogs.blogs.map(b => ({
        ...b,
        content: b.content?.length > 500 ? b.content.slice(0, 500) + '...' : b.content,
      })) }
    : { blogs: [] };

  // Trim podcast transcripts
  const trimmedPodcasts = pcOk === 1
    ? { podcasts: podcasts.podcasts.map(p => ({
        ...p,
        transcript: p.transcript?.length > 800 ? p.transcript.slice(0, 800) + '...' : p.transcript,
      })) }
    : { podcasts: [] };

  // Build errors array
  const errors = [];
  if (pcOk === 0) errors.push('Could not fetch podcast feed');
  if (xOk === 0) errors.push('Could not fetch X feed');
  if (blOk === 0) errors.push('Could not fetch blog feed');

  // Cache info
  const cacheInfo = [];
  for (const [src, file] of [['podcasts', 'feed-podcasts.json'], ['x', 'feed-x.json'], ['blogs', 'feed-blogs.json']]) {
    const filePath = join(CACHE_DIR, file);
    if (existsSync(filePath)) {
      try {
        const st = statSync(filePath);
        cacheInfo.push({ source: src, cacheAge: Math.floor(st.mtimeMs / 1000) });
      } catch {}
    }
  }

  const output = {
    status: errors.length === 0 ? 'ok' : 'partial',
    generatedAt: new Date().toISOString(),
    repo: REPO,
    cacheDir: CACHE_DIR,
    cacheInfo,
    available: { podcasts: pcOk, x: xOk, blogs: blOk },
    stats: {
      podcastEpisodes: pcCount,
      totalTweets: xTotal,
      xShown,
      blogPosts: blCount,
    },
    podcasts: trimmedPodcasts.podcasts,
    x: topX,
    blogs: trimmedBlogs.blogs,
    errors: errors.length === 0 ? null : errors,
  };

  process.stdout.write(JSON.stringify(output, null, 2));
}

main().catch(err => {
  console.error('Error:', err.message);
  process.exit(1);
});