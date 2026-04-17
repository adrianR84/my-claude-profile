---
name: mcp-tavily-mcp
description: "Web search, content extraction, and research automation via Tavily. Use whenever you need current information from the internet — news, facts, prices, documentation, or multi-source research. Triggers whenever the user asks about anything that requires up-to-date web content, extract content from specific URLs, crawl a website structure, or perform research across multiple sources. The user doesn't need to say 'Tavily' — phrases like 'look up', 'search for', 'find current', 'check the docs for', 'what's the latest on', 'research', or referencing specific websites all indicate this skill is needed."
version: 1.0.0
author: mcptoskill
license: MIT
metadata: {"claude":{"version":"1.0","category":"mcp"}}
---

# tavily-mcp



## Quick Start

```bash
C:\Users\adria\.claude\skills/mcp-tavily-mcp/scripts/mcp-tavily-mcp.sh <tool-name> '<json-args>'
```

## Tools

### tavily_search

Search the web for current information on any topic. Use for news, facts, or data beyond your knowledge cutoff. Returns snippets and source URLs.

**Parameters:**
  - `query` (string) (required): Search query
  - `max_results` (integer) (optional): The maximum number of search results to return
  - `search_depth` (string) (optional): The depth of the search. 'basic' for generic results, 'advanced' for more thorough search, 'fast' for optimized low latency with high relevance, 'ultra-fast' for prioritizing latency above all else
  - `topic` (string) (optional): The category of the search. This will determine which of our agents will be used for the search
  - `time_range` (string) (optional): The time range back from the current date to include in the search results
  - `include_images` (boolean) (optional): Include a list of query-related images in the response
  - `include_image_descriptions` (boolean) (optional): Include a list of query-related images and their descriptions in the response
  - `include_raw_content` (boolean) (optional): Include the cleaned and parsed HTML content of each search result
  - `include_domains` (array) (optional): A list of domains to specifically include in the search results, if the user asks to search on specific sites set this to the domain of the site
  - `exclude_domains` (array) (optional): List of domains to specifically exclude, if the user asks to exclude a domain set this to the domain of the site
  - `country` (string) (optional): Boost search results from a specific country. Must be a full country name (e.g., 'United States', 'Japan', 'Germany'). ISO country codes (e.g., 'us', 'jp') are not supported. Available only if topic is general. See https://docs.tavily.com/documentation/api-reference/search for the full list of supported countries.
  - `include_favicon` (boolean) (optional): Whether to include the favicon URL for each result
  - `start_date` (string) (optional): Will return all results after the specified start date. Required to be written in the format YYYY-MM-DD.
  - `end_date` (string) (optional): Will return all results before the specified end date. Required to be written in the format YYYY-MM-DD

```bash
C:\Users\adria\.claude\skills/mcp-tavily-mcp/scripts/mcp-tavily-mcp.sh tavily_search '{"query":"<query>"}'
```

### tavily_extract

Extract content from URLs. Returns raw page content in markdown or text format.

**Parameters:**
  - `urls` (array) (required): List of URLs to extract content from
  - `extract_depth` (string) (optional): Use 'advanced' for LinkedIn, protected sites, or tables/embedded content
  - `include_images` (boolean) (optional): Include images from pages
  - `format` (string) (optional): Output format
  - `include_favicon` (boolean) (optional): Include favicon URLs
  - `query` (string) (optional): Query to rerank content chunks by relevance

```bash
C:\Users\adria\.claude\skills/mcp-tavily-mcp/scripts/mcp-tavily-mcp.sh tavily_extract '{"urls":"<urls>"}'
```

### tavily_crawl

Crawl a website starting from a URL. Extracts content from pages with configurable depth and breadth.

**Parameters:**
  - `url` (string) (required): The root URL to begin the crawl
  - `max_depth` (integer) (optional): Max depth of the crawl. Defines how far from the base URL the crawler can explore.
  - `max_breadth` (integer) (optional): Max number of links to follow per level of the tree (i.e., per page)
  - `limit` (integer) (optional): Total number of links the crawler will process before stopping
  - `instructions` (string) (optional): Natural language instructions for the crawler. Instructions specify which types of pages the crawler should return.
  - `select_paths` (array) (optional): Regex patterns to select only URLs with specific path patterns (e.g., /docs/.*, /api/v1.*)
  - `select_domains` (array) (optional): Regex patterns to restrict crawling to specific domains or subdomains (e.g., ^docs\.example\.com$)
  - `allow_external` (boolean) (optional): Whether to return external links in the final response
  - `extract_depth` (string) (optional): Advanced extraction retrieves more data, including tables and embedded content, with higher success but may increase latency
  - `format` (string) (optional): The format of the extracted web page content. markdown returns content in markdown format. text returns plain text and may increase latency.
  - `include_favicon` (boolean) (optional): Whether to include the favicon URL for each result

```bash
C:\Users\adria\.claude\skills/mcp-tavily-mcp/scripts/mcp-tavily-mcp.sh tavily_crawl '{"url":"<url>"}'
```

### tavily_map

Map a website's structure. Returns a list of URLs found starting from the base URL.

**Parameters:**
  - `url` (string) (required): The root URL to begin the mapping
  - `max_depth` (integer) (optional): Max depth of the mapping. Defines how far from the base URL the crawler can explore
  - `max_breadth` (integer) (optional): Max number of links to follow per level of the tree (i.e., per page)
  - `limit` (integer) (optional): Total number of links the crawler will process before stopping
  - `instructions` (string) (optional): Natural language instructions for the crawler
  - `select_paths` (array) (optional): Regex patterns to select only URLs with specific path patterns (e.g., /docs/.*, /api/v1.*)
  - `select_domains` (array) (optional): Regex patterns to restrict crawling to specific domains or subdomains (e.g., ^docs\.example\.com$)
  - `allow_external` (boolean) (optional): Whether to return external links in the final response

```bash
C:\Users\adria\.claude\skills/mcp-tavily-mcp/scripts/mcp-tavily-mcp.sh tavily_map '{"url":"<url>"}'
```

### tavily_research

Perform comprehensive research on a given topic or question. Use this tool when you need to gather information from multiple sources, including web pages, documents, and other resources, to answer a question or complete a task. Returns a detailed response based on the research findings. Rate limit: 20 requests per minute.

**Parameters:**
  - `input` (string) (required): A comprehensive description of the research task
  - `model` (string) (optional): Defines the degree of depth of the research. 'mini' is good for narrow tasks with few subtopics. 'pro' is good for broad tasks with many subtopics

```bash
C:\Users\adria\.claude\skills/mcp-tavily-mcp/scripts/mcp-tavily-mcp.sh tavily_research '{"input":"<input>"}'
```

### tavily_skill

Search documentation for any library, API, or tool. Returns relevant, structured documentation chunks assembled for your specific query. When working with a specific library, always pass the library name for best results.

**Parameters:**
  - `query` (string) (required): Natural language query about a library/API/tool (e.g. 'celery beat periodic tasks', 'SSE streaming with App Router')
  - `library` (string) (optional): Library/package name to target (e.g. 'nextjs', 'celery', 'httpx'). When provided, retrieval is constrained to this library.
  - `language` (string) (optional): Programming language of the current project (e.g. 'python', 'typescript', 'go'). Boosts results matching this language.
  - `task` (string) (optional): What you're trying to do. Affects which documentation sections are prioritized.
  - `context` (string) (optional): Brief description of your current project/stack (e.g. 'FastAPI app with Redis broker'). Helps tailor the response.
  - `max_tokens` (integer) (optional): Maximum tokens in response

```bash
C:\Users\adria\.claude\skills/mcp-tavily-mcp/scripts/mcp-tavily-mcp.sh tavily_skill '{"query":"<query>"}'
```
