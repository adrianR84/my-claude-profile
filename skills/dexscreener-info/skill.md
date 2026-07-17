---
name: dexscreener-info
description: >
  Extract token info from DexScreener URLs — name, symbol, contract, chain, website, twitter, github, telegram. Returns structured JSON.
---

# DexScreener Token Info

Fetches and extracts structured token/project information from one or more DexScreener URLs using parallel subagents for speed.

## Input

One or more DexScreener URLs **or** bare contract addresses. Examples:
- URL: `https://dexscreener.com/solana/5c4HyD2rSShqnTsf5z3SaoD2H3GE452u2CUuYjviBAGS`
- Bare contract: `5c4HyD2rSShqnTsf5z3SaoD2H3GE452u2CUuYjviBAGS`

**Parsing rule:** If the input matches a URL, extract chainId and tokenAddress from the path. If it looks like a bare contract address (no slashes, no scheme), treat it as a tokenAddress with chainId unknown.

**For bare contracts:** Detect chain from address format first:
- Starts with `0x` and is 42 chars → `ethereum`
- Otherwise (base58, 32-44 chars) → `solana`
Try the detected chain only. If no pair found, fall back to trying `solana` then `ethereum` then `bsc` sequentially until a pair is found.

## Workflow (2 stages)

Use the **Workflow** tool:

**Stage 1 — Fetch DexScreener (parallel)**
```
phase('Fetch')
pipeline(urls, url => agent(
  `Fetch token data for: ${url}

  1. Determine if input is a full DexScreener URL or a bare contract address.
     - URL: parse chainId and tokenAddress from the path.
     - Bare contract: tokenAddress = the string. Detect chain by format:
       * 0x + 40 hex chars (42 total) → base
       * otherwise (base58, 32-44 chars) → solana
       Try the detected chain first. If no pair found, fall back to trying solana, base, bsc sequentially until a pair is found.
  2. Call GET https://api.dexscreener.com/token-pairs/v1/{chainId}/{tokenAddress}
     using the fetch tool (Node.js/undici). Parse JSON response.
  3. The API returns a JSON array directly. Find the first pair with a baseToken.
  4. Extract: name, symbol, contractAddress (baseToken.address), chainId, website,
     twitter (normalize bare @handle to https://x.com/handle),
     telegram, github.
  5. Return a JSON object with all found fields. Set needsGithubScrape = true
     if github is null AND website is not null.
  6. If error: return { url: "...", error: "message", needsGithubScrape: false }.

  Return ONLY the JSON object. Nothing else.`
, { label: 'fetch-dexscreener', phase: 'Fetch', model: 'sonnet', schema: {
  type: 'object',
  properties: {
    name: { type: ['string','null'] },
    symbol: { type: ['string','null'] },
    contractAddress: { type: ['string','null'] },
    chainId: { type: ['string','null'] },
    website: { type: ['string','null'] },
    twitter: { type: ['string','null'] },
    github: { type: ['string','null'] },
    telegram: { type: ['string','null'] },
    error: { type: ['string','null'] },
    url: { type: 'string' },
    needsGithubScrape: { type: 'boolean' }
  },
  required: ['url', 'needsGithubScrape']
}}))
```

**Stage 2 — Scrape GitHub for missing items (this runs in the main agent, which CAN invoke skills)**
After Stage 1 completes, for every result where `needsGithubScrape === true` AND `github === null`:
1. Call the **website-scraper** skill on that result's `website` URL
2. Extract the `github` field from the skill's response
3. Set `github` on that result to the scraped value (or keep null if not found)

Return the final JSON array in input order, with github enriched from scraping where applicable.

## Send to Project Checker API (mandatory prompt)

After returning the results, you MUST ask the user whether to import the data to Project Checker. Do not skip this step — even if the user has not explicitly requested it.

1. **Read `.env`** from the current working directory. Parse it manually (do not use a library) to collect ALL values of `PROJECT_CHECKER_URL` — standard .env parsers drop duplicates, so split each line, strip whitespace, and collect every key=value pair where the key starts with `PROJECT_CHECKER_URL`. Extract `PROJECT_CHECKER_API` (single token, shared across all endpoints).

2. **Ask the user** whether they want to import. Present two options:
   - **Bulk** (Recommended): one POST with an array of all results
   - **Single**: one POST per project
   Default to **bulk** if user doesn't specify.

3. **Build the payload** — map the results to the Project Checker schema:
   ```json
   {
     "name": "...",
     "website": "...",
     "github": "...",
     "twitter": "...",
     "symbol": "...",
     "contractAddress": "...",
     "chainId": "..."
   }
   ```
   Null fields may be omitted. For bulk, wrap in an array `[{...}, {...}]`.

4. **POST to each `PROJECT_CHECKER_URL*` endpoint** using Node.js fetch (undici):
   ```
   POST <each PROJECT_CHECKER_URL*>
   Authorization: Bearer <PROJECT_CHECKER_API>
   Content-Type: application/json
   Body: <payload>
   ```
   Send to all discovered endpoints in parallel.

5. **Report per-endpoint success/failure** — show each endpoint's response or error.

## Output Format

```json
[
  {
    "name": "Token Name",
    "symbol": "SYMBOL",
    "contractAddress": "7vfCXTUXx5WJV5JADk17DUJ4ksgau7utNKj4b963voxs",
    "chainId": "solana",
    "website": null,
    "twitter": null,
    "github": null,
    "telegram": null
  }
]
```

For errors:
```json
{"url": "https://dexscreener.com/...", "error": "Human-readable error message"}
```

## Field Rules
- `twitter`: full `https://x.com/...` URL, never a bare `@handle`. Expand bare handles.
- `github`: full `https://github.com/...` URL or null
- `telegram`: full `https://t.me/...` URL or null
- `website`: direct URL string or null
- All missing fields → null
- Partial success → return results for all URLs, errors for failed ones
