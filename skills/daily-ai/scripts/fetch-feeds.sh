#!/bin/bash
# =============================================================================
# Daily AI — Fetch Feeds
# Fetches the 3 JSON feeds from GitHub, parses and filters them, outputs a
# single JSON blob to stdout for the LLM to remix into a digest.
#
# Usage: bash /path/to/fetch-feeds.sh
# Output: JSON to stdout
# =============================================================================

set -e

# -- Defaults ----------------------------------------------------------------
REPO="${DAILY_AI_REPO:-zarazhangrui/follow-builders}"
BASE="https://raw.githubusercontent.com/${REPO}/main"
X_LIMIT="${DAILY_AI_X_LIMIT:-20}"

# -- Dependency check ---------------------------------------------------------
if ! command -v jq &>/dev/null; then
  echo "ERROR: jq is required but not installed." >&2
  echo "Install: https://jqlang.github.io/jq/" >&2
  exit 1
fi

if ! command -v curl &>/dev/null; then
  echo "ERROR: curl is required but not installed." >&2
  exit 1
fi

# -- Fetch all 3 feeds concurrently --------------------------------------------
PODCASTS=$(curl -fs "${BASE}/feed-podcasts.json" 2>/dev/null) || PODCASTS=""
X_FEED=$(curl -fs "${BASE}/feed-x.json" 2>/dev/null) || X_FEED=""
BLOGS=$(curl -fs "${BASE}/feed-blogs.json" 2>/dev/null) || BLOGS=""

# -- Validate each feed -------------------------------------------------------
PC_OK=$(echo "$PODCASTS" | jq -e '.podcasts' >/dev/null 2>&1 && echo 1 || echo 0)
X_OK=$(echo "$X_FEED" | jq -e '.x' >/dev/null 2>&1 && echo 1 || echo 0)
BL_OK=$(echo "$BLOGS" | jq -e '.blogs' >/dev/null 2>&1 && echo 1 || echo 0)

# -- Stats --------------------------------------------------------------------
PC_COUNT=$(echo "$PODCASTS" | jq -e '.podcasts | length' 2>/dev/null || echo 0)
X_TOTAL=$(echo "$X_FEED" | jq -e '[.x[].tweets] | flatten | length' 2>/dev/null || echo 0)
BL_COUNT=$(echo "$BLOGS" | jq -e '.blogs | length' 2>/dev/null || echo 0)

# -- Top X tweets by engagement -----------------------------------------------
# Score = likes + (retweets * 2). Sort globally, take top N.
# We need handle and name attached to each tweet — those live in the parent x entry.
if [[ "$X_OK" == "1" && "$X_TOTAL" -gt 0 ]]; then
  TOP_X=$(echo "$X_FEED" | jq \
    --argjson limit "$X_LIMIT" \
    'def score: .likes + (.retweets * 2);
     [.x[] | select(.tweets | length > 0)] |
     map(.handle as $h | .name as $n | .tweets[] | . + {bx_handle: $h, bx_name: $n}) |
     sort_by(score) | reverse | .[0:$limit]
    ' 2>/dev/null)
  X_SHOWN=$(echo "$TOP_X" | jq 'length')
else
  TOP_X="[]"
  X_SHOWN=0
fi

# -- Blog posts with content trimmed to a summary-friendly length -------------
if [[ "$BL_OK" == "1" ]]; then
  # Truncate content to first 500 chars for the digest payload
  TRIMMED_BLOGS=$(echo "$BLOGS" | jq '
    .blogs |= map({
      source, name, title, url, publishedAt, author,
      description,
      content: (.content | if length > 500 then .[0:500] + "..." else . end)
    })
  ' 2>/dev/null)
else
  TRIMMED_BLOGS="{\"blogs\":[]}"
fi

# -- Podcast episodes with transcript trimmed ---------------------------------
if [[ "$PC_OK" == "1" ]]; then
  # Truncate transcript to first 800 chars for the digest payload
  TRIMMED_PODCASTS=$(echo "$PODCASTS" | jq '
    .podcasts |= map({
      source, name, title, guid, url, publishedAt,
      transcript: (.transcript | if length > 800 then .[0:800] + "..." else . end)
    })
  ' 2>/dev/null)
else
  TRIMMED_PODCASTS="{\"podcasts\":[]}"
fi

# -- Errors -------------------------------------------------------------------
ERRORS="[]"
if [[ "$PC_OK" == "0" ]]; then
  ERRORS=$(echo "$ERRORS" | jq '. + ["Could not fetch podcast feed"]' 2>/dev/null)
fi
if [[ "$X_OK" == "0" ]]; then
  ERRORS=$(echo "$ERRORS" | jq '. + ["Could not fetch X feed"]' 2>/dev/null)
fi
if [[ "$BL_OK" == "0" ]]; then
  ERRORS=$(echo "$ERRORS" | jq '. + ["Could not fetch blog feed"]' 2>/dev/null)
fi

# -- Assemble output -----------------------------------------------------------
OUTPUT=$(jq -n \
  --argjson podcasts "$((PC_OK == 1))" \
  --argjson x "$((X_OK == 1))" \
  --argjson blogs "$((BL_OK == 1))" \
  --argjson pc_count "$PC_COUNT" \
  --argjson x_total "$X_TOTAL" \
  --argjson bl_count "$BL_COUNT" \
  --argjson x_shown "$X_SHOWN" \
  --argjson top_x "$TOP_X" \
  --arg trimmed_podcasts "$TRIMMED_PODCASTS" \
  --arg trimmed_blogs "$TRIMMED_BLOGS" \
  --argjson errors "$ERRORS" \
  --arg repo "$REPO" \
  --arg generated_at "$(date -u +%Y-%m-%dT%H:%M:%SZ 2>/dev/null || date -u +%Y-%m-%dT%H:%M:%SZ)" \
  '{
    status: (if ($errors | length) == 0 then "ok" else "partial" end),
    generatedAt: $generated_at,
    repo: $repo,
    available: {podcasts: $podcasts, x: $x, blogs: $blogs},
    stats: {
      podcastEpisodes: $pc_count,
      totalTweets: $x_total,
      xShown: $x_shown,
      blogPosts: $bl_count
    },
    podcasts: ($trimmed_podcasts | fromjson | .podcasts),
    x: $top_x,
    blogs: ($trimmed_blogs | fromjson | .blogs),
    errors: (if ($errors | length) == 0 then null else $errors end)
  }')

echo "$OUTPUT"
