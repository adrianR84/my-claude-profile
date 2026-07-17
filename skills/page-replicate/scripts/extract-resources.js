#!/usr/bin/env node
// Normalizes chrome-devtools evaluate_script JSON output into clean resource arrays.
const fs = require('fs');

const input = JSON.parse(fs.readFileSync(process.argv[2], 'utf8'));

const out = {
  stylesheets: input.links
    .filter(l => l.rel === 'stylesheet' || l.as === 'style')
    .map(l => ({ url: l.href, type: l.type || 'text/css' })),

  scripts: input.scripts.map(s => ({
    url: s.src,
    type: s.type,
    async: !!s.async,
    defer: !!s.defer,
    module: !!s.module,
  })),

  images: input.imgs
    .filter(i => i.src && !i.src.startsWith('data:'))
    .map(i => ({ url: i.src, alt: i.alt || '', w: i.w, h: i.h })),

  videos: input.videos
    .filter(v => v.src && !v.src.startsWith('data:'))
    .map(v => ({ url: v.src, type: v.type || '' })),

  fonts: input.fonts.map(f => ({
    family: f.family,
    weight: f.weight,
    style: f.style,
    status: f.status,
  })),

  meta: input.meta || [],

  cssVars: input.rootVars || {},

  classes: [], // populated by grep in build-prompt.sh

  viewport: input.viewport,
  title: input.title,
  lang: input.lang,
  charset: input.charset,
};

const outPath = process.argv[3] || '/tmp/page-replicate/normalized.json';
fs.writeFileSync(outPath, JSON.stringify(out, null, 2));
console.log('Normalized resources →', outPath);
