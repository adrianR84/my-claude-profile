---
name: daily-ai
description: Get a daily AI industry digest from curated podcasts, X/Twitter, and blogs. Use whenever someone says "AI digest", "what's happening in AI", "AI news today", "AI updates", or invokes /daily-ai. Fetches pre-generated feed files from GitHub and presents a curated summary. Does NOT do live web search.
allowed-tools: Bash(bash *)
---

# Daily AI Digest

Fetch the latest AI industry digest from curated podcasts, X/Twitter builders, and blog posts.

## Sources

- **6 podcasts**: Latent Space, Training Data, No Priors, Unsupervised Learning, MAD Podcast, AI & I
- **25 X builders**: Andrej Karpathy, Sam Altman, Swyx, Amanda Askell, Guillermo Rauch, Aaron Levie, and more
- **2 blogs**: Anthropic Engineering, Claude Blog

Data from [zarazhangrui/follow-builders](https://github.com/zarazhangrui/follow-builders) — updated daily by GitHub Actions. This skill is inspired by the original follow-builders project and uses the same feed sources.

## Requires

- `jq` — install if missing:
  - Windows: `winget install jqlang.jq` or `choco install jq`
  - macOS: `brew install jq`
  - Linux: `sudo apt install jq` / `sudo dnf install jq`

## Run

```bash
bash C:/Users/adria/.claude/skills/daily-ai/scripts/fetch-feeds.sh
```

The script fetches all 3 feeds from GitHub, validates JSON, caps X posts at top 10 by engagement (`likes + retweets*2`), and outputs a single JSON blob to stdout.

Override repo with `DAILY_AI_REPO=owner/repo` env var. Override X post limit with `DAILY_AI_X_LIMIT=20`.

## Output Format

The script outputs JSON with this shape:

```json
{
  "status": "ok",
  "generatedAt": "2026-04-21T20:08:52Z",
  "repo": "zarazhangrui/follow-builders",
  "available": {"podcasts": 1, "x": 1, "blogs": 1},
  "stats": {
    "podcastEpisodes": 1,
    "totalTweets": 32,
    "xShown": 10,
    "blogPosts": 1
  },
  "podcasts": [{...}],
  "x": [{...}],
  "blogs": [{...}],
  "errors": null
}
```

- `podcasts[].transcript` is truncated to 800 chars for payload size
- `blogs[].content` is truncated to 500 chars
- `x[]` contains only the top 10 tweets globally by engagement
- `x[].bx_handle` and `x[].bx_name` are the tweet author's handle and display name

## Remix Prompt

After running the script, take the JSON output and present it to the LLM with this prompt:

```
You are writing a daily AI digest for a technically sophisticated reader
(engineer, researcher, or builder). The reader is busy. Output plain text
with box-drawing characters only — no markdown tables.

Stats: {podcastEpisodes} podcast episodes, {xShown} X posts, {blogPosts} blog posts
Source: github.com/{repo}

## PODCASTS
For each episode provide: show name, episode title, 2-3 sentence summary
focused on why it matters (key takeaways, notable quotes), and the YouTube link.

## X / TWITTER
For each tweet provide: @handle (full name), full tweet text verbatim
(no paraphrase), engagement (likes, RTs), and the full https://x.com URL.

## BLOGS
For each post provide: blog name, article title, 2-3 sentence summary, and the full URL.

## Header
═══════════════════════════════════════════════════════
  AI DIGEST  •  {date}  •  {pc_count} podcasts  •  {x_shown} posts  •  {bl_count} blogs
═══════════════════════════════════════════════════════

## Footer
═══════════════════════════════════════════════════════
  Source: github.com/{repo}
═══════════════════════════════════════════════════════
```

## Example Output

```
═══════════════════════════════════════════════════════
  AI DIGEST  •  April 21, 2026  •  1 podcasts  •  10 posts  •  1 blogs
═══════════════════════════════════════════════════════

## PODCASTS
──────────────────────────────────────────────────────
  [No Priors]
  "The Agentic Economy: How AI Agents Will Transform the Financial System"
  No Priors sits down with Jeremy Allaire, Circle's CEO, for a wide-ranging
  conversation on stablecoin infrastructure, AI agentic payments, and what
  blockchain-based dollar systems look like in an agent-driven economy.
  youtube.com/watch?v=eyobeqMdbeI

## X / TWITTER
──────────────────────────────────────────────────────
  @sama (Sam Altman)
  Tim Cook is a legend. I am very thankful for everything he has done and I
  am very thankful for Apple.
  28.5K likes  •  1.5K RTs
  https://x.com/sama/status/2046330825265086712

  @claudeai (Claude)
  In Cowork, Claude can now build live artifacts: dashboards and trackers
  connected to your apps and files.
  13K likes  •  872 RTs
  https://x.com/claudeai/status/2046328619249684989

## BLOGS
──────────────────────────────────────────────────────
  [Claude Blog]
  "Preparing your security program for AI-accelerated offense"
  Anthropic's security team outlines a practical playbook for defenders as AI
  accelerates offense — covering patch velocity, vulnerability triage at scale,
  zero-trust architecture, and autonomous red-teaming. Essential reading given
  how quickly AI-driven exploit generation is maturing.
  https://claude.com/blog/preparing-your-security-program-for-ai-accelerated-offense

═══════════════════════════════════════════════════════
  Source: github.com/zarazhangrui/follow-builders
═══════════════════════════════════════════════════════
```

## Partial Failure

If `status` is `"partial"`, check the `errors` array and note which feeds were unavailable. Present the digest with available feeds and mention the failure in the output.
