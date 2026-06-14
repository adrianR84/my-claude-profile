---
name: home-report
description: |
  Analyzes residential property survey PDFs (Home Reports) and generates a comprehensive structured analysis.
  Use this skill whenever the user provides a PDF of a Scottish Home Report, property survey, EPC, or similar
  residential property document — whether as a local file path or a URL. Also trigger when user asks to
  "analyze home report", "process property survey", "generate home report", "read property PDF", or
  similar requests involving property inspection reports. This skill downloads the PDF, extracts all content,
  researches the location via web search, and produces a full structured report with valuation, condition,
  energy, location, and risk sections.
---

# Home Report Analysis Skill

## Overview

This skill processes a residential property survey PDF (Scottish Home Report format) and produces a comprehensive structured analysis. It handles local files and URLs, researches the location, and can export to HTML.

## Output Modes

**Default:** Full comprehensive report (all sections).
**Red flag mode:** Triggered when the user says "show me the red flags", "is this property safe to buy?", "just the issues", "what's wrong with this property", or similar — a short, focused output on deal-breakers and urgent issues only. Produces a condensed report (see Short Output Format below) without the full sections.

Both modes use the same steps for data gathering (PDF reading, location research, cost estimates). Only the output formatting differs. **HTML export is available for both modes** — Step 8 generates the appropriate HTML variant based on which mode was used.

**Regenerating a report:** If the user asks to regenerate, re-export, or re-display a report (phrases: "regenerate", "show the report again", "html version", "export to html", "save as html", "make html report", "update html", "display the report", "show the report"), read from the existing `report.md` file first — do not re-process the PDF from scratch. Also read `property-link.txt` from the same folder to restore any external listing URL provided with the original request — reuse it to fetch room dimensions, property image, floorplan, and sold properties. Only re-run from Step 1 if the user explicitly says "start from zero", "re-analyze", "process the PDF again", or similar. This applies to both terminal and HTML output.

**External link (Zoopla / Rightmove):** If the user provides a Zoopla or Rightmove URL alongside the PDF, fetch the page and use it to complement the home report data. Prioritise home report data over external link data — if they conflict, keep the home report value and note the discrepancy. Pull room dimensions from the listing if available; if room dimensions are found (from either source), add a **Room Dimensions** section to the report. Also extract: (1) the property's main listing image URL, (2) the floorplan image URL. For the floorplan URL, strip the `_max_296x197` suffix before the file extension (e.g. `_max_296x197.jpeg` → `.jpeg`). Pass both image URLs to the HTML template. **Save this URL to `./home-reports/<pdf-name>/property-link.txt`** so it can be reused when regenerating the report.

**Floorplan image analysis:** If a floorplan image URL is available (from the external listing), use `mcp__MiniMax__understand_image` to analyze it. Prompt: "Analyze this floorplan and extract all room names with their dimensions (width x length in metres or feet). List each room separately. If total floor area is known, cross-check that room sizes sum reasonably." Use the extracted room data to supplement or validate the Room Dimensions section. If the floorplan reveals rooms not listed in the PDF, add them and note the source.

**Rightmove Sold Properties:** After extracting the postcode from the PDF, construct a Rightmove URL using the postcode (with space, lowercase). For example, if the postcode is "KY6 3DH", use `https://www.rightmove.co.uk/house-prices/ky6-3dh.html`. Fetch this page and extract all sold property records — address, sale price, sale date, property type, bedrooms, listing link, and image. Filter to last 3 years only. Sort by most recent sale first. Each address must be a clickable link to its Rightmove listing (opens in new tab). Save this data in report.md and include it in the HTML report.

### Step 1: Acquire the PDF

**If the input is a URL:**
- Download the PDF to `./home-reports/` (create if not exists)
- Create a subfolder named after the PDF filename (without extension)
- Save the PDF inside that subfolder
- Use `curl -L -o` to follow redirects and download

**If the input is a local path:**
- Copy the PDF file to `./home-reports/<pdf-name-without-extension>/<original-filename>` (create subfolder if not exists)
- Use the copied file as the working PDF

**Base directory for all outputs:** `./home-reports/<pdf-name-without-extension>/`

**Important:** Every output (the PDF copy, the HTML file, any saved reports) goes inside this same subfolder. The HTML must always be in the same folder as the PDF.

### Step 2: Read the PDF

Use `pdf-mcp` tools to read the full PDF content:
1. Call `pdf_info` with `detail: true` to get page count and structure
2. Call `pdf_read_all` with `max_pages` set to the full page count
3. Parse the extracted text to identify sections

**Size/complexity handling:** If the PDF exceeds ~50 pages, check whether it is image-only (high raster image count in pdf_info, 0 text chars). If image-only and large, skip full text extraction and use `pdf_render_pages` + `WebSearch` to research the address and pull comparable data from public sources — this is faster and more reliable than attempting OCR on a100+ page scanned document.

**Fallback if pdf-mcp returns no text or an error:**
1. Try `pdf_search` with common property terms (e.g., "valuation", "EPC", "condition") — sometimes this extracts text that `pdf_read_all` misses
2. If still no text, use `WebFetch` on the URL (if it was a URL) — sometimes returns a redirect URL that can be fetched directly
3. If the PDF is a scanned/image-only document (pdf_info shows high raster image count, 0 text chars), try `pdf_render_pages` to get image data, then use `WebSearch` to research the address and pull comparable data from public sources
4. If all above fail, still produce a partial report with whatever was captured and note: "Full text extraction failed — report based on partial data. Manual review recommended."

### Step 3: Parse Content

Extract and organize the following from the PDF text:

**Property Identification:**
- Address (street, city, postcode)
- Property type (end-terrace, detached, flat, etc.)
- Accommodation (rooms, bedrooms, bathrooms, floor area in m²)
- Age / year built
- Tenure (ownership, leasehold, etc.)
- **Council Tax Band** — this is found in the **Property Questionnaire** section (separate from the Single Survey), not always in the Single Survey itself. Cross-reference both sections. **Conflict resolution:** If the Property Questionnaire and Single Survey give different bands, prefer the Property Questionnaire value (it reflects the official local authority record) and note the discrepancy in the report.

**Valuation:**
- Market value (from Single Survey section)
- Reinstatement / insurance value

**EPC Data:**
- Energy Efficiency Rating (current band and number, e.g., D 68)
- Environmental Impact Rating (current band and number, e.g., D 67)
- Primary energy indicator (kWh/m²/year)
- CO2 emissions (kg CO2/m²/yr)
- Potential ratings
- Estimated energy costs (3 years)
- Recommended improvements (with indicative costs and typical savings)

**Condition:**
- All category ratings (1, 2, or 3) per element
- Note any Category 2 or 3 items — these require attention

**Construction:**
- Walls (material, construction type)
- Roof (type, covering, insulation)
- Windows (type, glazing, installation year)
- Doors
- Rainwater goods
- Chimney stacks
- Garages / outbuildings

**Services:**
- Electricity (mains/private, last tested date)
- Gas (mains/private, meter location)
- Water (mains/private)
- Heating (type, fuel, boiler model, installation year)
- Drainage
- Central heating controls

**Internal:**
- Kitchen (installation year, units description)
- Bathroom (fittings)
- Ceilings, walls, floors
- Internal joinery
- Decorations

**Legal / Conveyancer Notes:**
- Rights of way
- Shared accesses
- Boundaries
- Planning issues
- Any assumptions made

**Mortgage Valuation:**
- Market value
- Garage/parking
- Special risks
- Retention recommended / amount

### Step 4: Identify Strong and Weak Points

**Strong Points (bonuses):**
- Recent renovations (kitchen, bathroom, windows, doors)
- Triple glazing
- Good insulation (270mm loft)
- Modern boiler (within last 10 years)
- No Category 2 or 3 issues
- Good decorative order
- Desirable location features
- Off-street parking
- Smoke detectors / security systems
- Any guarantees transferable

**Weak Points (minuses):**
- Category 2 or 3 repair items
- Poor energy rating (Band E or below)
- No cavity wall insulation
- No floor insulation
- No maintenance contract on heating
- Old electrical installation (no recent test)
- Suspended floors with no insulation
- Timber deck with limited lifespan
- Textured finishes (Artex) without asbestos testing
- No smoke detectors (pre-2022 requirement gap)
- Any dampness, rot, or infestation signs
- Missing documentation (no guarantees, no service records)

### Step 5: Research the Location

**Default:** Shallow inline search — perform a single `WebSearch` covering all 6 topics at once (or in quick succession if needed). No subagents. Produce a concise location summary with one line per topic.

**On demand — subagents:** Triggered when the user explicitly asks for subagents research, detailed location research, or research all topics in detail ("subagents research", "detailed location research", "research all topics in depth", or similar). Spawn 6 parallel subagents — one per topic — all at the same time. Do NOT search topics sequentially.

**Shallow search (default):**
Use `WebSearch` (or `mcp__MiniMax__web_search` as fallback) with a combined query covering all topics:
```
Research the following for [TOWN/AREA NAME, extracted from property address]: nearest supermarkets and shops, nearby schools with ratings, commuting options (train/bus), local crime rate, lifestyle/amenities, and nearest health facilities (hospitals, GPs, pharmacies). Return one line per topic with key details and how it compares to the local average.
```

**Topics to research (one subagent each):**
1. **Supermarkets / Shops:** Nearest supermarkets and shopping centres
2. **Schools:** Nearby primary and secondary schools with ratings
3. **Commuting:** Train stations, bus routes, major road links to nearby cities/towns
4. **Crime rate:** Local crime statistics and safety assessment
5. **Lifestyle / Liveability:** General info — amenities, parks, community, pros/cons
6. **Health:** Nearest hospitals, GP surgeries, health centres, gyms and pharmacies

**Subagent prompt template:**
```
Search for information about [TOPIC] in [TOWN/AREA NAME, extracted from property address].
Return a concise summary with specific details (names, distances, ratings, times, costs).
Also note how these compare to the local/regional average — e.g., "crime rate is X% above/below the [Town] average", "this school rates in the top Y% for [Area]", "commute time is typical for the area" etc.
```

**After all 6 subagents complete**, compile the results into the LOCATION RESEARCH section.

**Resilience:** If any subagent fails or returns no useful data, retry it once with the same prompt. If it fails again, record the topic as "data unavailable — [brief reason]" rather than leaving it blank. For the two most important topics (Schools, Crime rate), if both retries fail, try a broader search (e.g., search the council area name instead of the town name).

**Town/area extraction:** Parse the address from the PDF to identify the town. Use the postcode suffix (e.g., "ML7" in "ML7 4DF") to identify the region — UK postcodes encode location. Search the town name + postcode area for best results (e.g., "Shotts ML7" or "Wishaw ML2"). For Scottish properties, also check the council area (North Lanarkshire, South Lanarkshire, etc.) as this affects school ratings and crime statistics.

### Step 5b: Rightmove Sold Properties

**Fetch sold property data from Rightmove:**
1. Extract the postcode from the PDF (e.g., "KY6 3DH")
2. Convert to the Rightmove URL format: `https://www.rightmove.co.uk/house-prices/ky6-3dh.html` (postcode with space, lowercase)
3. Fetch the page using `WebFetch`
4. Parse the sold property records — for each entry extract:
   - Full address
   - Sold price
   - Date sold
   - History of sale (price changes if available)
   - Property type (terrace, flat, semi-detached, detached)
   - Number of bedrooms
   - Link to the property listing
   - Image thumbnail URL
5. Filter to only properties sold in the last 3 years (36 months)
6. Sort by most recent sale first
7. Format each address as a link to its Rightmove listing page (opens in new tab)
8. If the Rightmove page fetch fails or returns no data, note "Sold property data unavailable" in the report
9. **Fallback — expand radius:** If no properties are found for the postcode (0 results in last 3 years), re-fetch the same URL with `?radius=0.25` appended (e.g. `https://www.rightmove.co.uk/house-prices/ky6-3dh.html?radius=0.25`). Parse and display these results the same way. If still no results, note "No sold properties found for this postcode in the last 3 years (even with expanded radius)."

**Include in report.md:** A "🏷️ Sold Properties" section with a table listing all records — address (as Rightmove link), sale price, sale date, property type, bedrooms — sorted newest first.

### Step 6: Handle Category 2/3 Issues

**First:** Read `references/repair-costs.md` and load the cost table into context — this is the safety net if subagents return no data.

1. **List all issues** with their category rating
2. **Extract property size** (m²) from the PDF — use this to scale estimates (e.g., roof cost per m², rewiring cost per m²)
3. **Spawn subagents in PARALLEL** — one per repair issue — to search for current local cost estimates. Use `WebSearch` (or `mcp__MiniMax__web_search` as fallback). If no Cat 2/3 issues exist, skip this step.

**Subagent prompt template (one per repair):**
```
Search for typical repair/replacement cost for: [ISSUE DESCRIPTION]
Property details: [TYPE], [SIZE] m², [BUILD YEAR if known], located in [TOWN/POSTCODE AREA, extracted from property address].
Focus on costs in the local/regional area (e.g., North Lanarkshire, South Lanarkshire, West Lothian, or whatever region the property is in).
Return: cost range (min–max), typical mid-point, key factors that affect price (e.g., size, location, material quality), and whether regional costs are above or below UK average.
```

4. **Compile results** into a "Repairs Needed" section with:
   - Issue description
   - Category rating
   - Estimated repair/replacement cost range (scaled to property size where relevant)
   - Urgency level (NOW for Cat 3, Soon for Cat 2)

**Fallback:** If any subagent fails, fill in the estimate from `references/repair-costs.md` (scaled to property size) rather than leaving it blank.

### Step 7: Produce the Full Report

**Short Output Format (red flag mode):**
```
## ⚠️ Property Red Flags — [Address]

**Verdict:** [SAFE TO BUY / CAUTION / DO NOT BUY] — [ONE SENTENCE REASON]

---

### 🚨 Urgent Issues (Category 3)
[Every Cat 3 item: element, issue, estimated cost, urgency]

---

### ⚠️ Plan Ahead (Category 2)
[Every Cat 2 item: element, issue, estimated cost, urgency]

---

### ⚡ Energy & Warmth
[EPC band, primary energy, estimated annual costs, top 1-2 improvement recommendations]

---

### 🔍 Deal Breakers
[Any structural issues, legal problems, or findings that would prevent a mortgage or require immediate expensive remediation]

---

### ✅ Positives
[Short bullet list of genuine strengths — up to 5]

---

### 📍 Location Snapshot
[One line per topic: crime, schools, commuting — compare to local average]

---

### 📐 Room Dimensions
[Table: room name | original dimensions (e.g. 12ft x 10ft) | converted to m² — only shown if dimensions are available from the home report or external listing]
```

**Full Report Format (default mode):**
```
## 🏠 Full Home Report Analysis
### [Property Address]

**Quick Summary:** [BEDROOMS]-bed [TYPE], £[VALUATION], EPC [BAND], [BUILT], [COUNCIL TAX] council tax — [ONE LINE: most important strong point] — [ONE LINE: most important concern or "no urgent issues"]

---

---

### 📋 PROPERTY SUMMARY
[Table with all key property info including: address, type, size, bedrooms, bathrooms, council tax band, built, tenure, EPC rating, asking price (if external link provided), home valuation, heating, electricity, gas, strong points, weak points, external link]

---

### 📷 PROPERTY IMAGE
[Property photo from Rightmove/Zoopla listing — only shown if external link provided]

---

### 🗺️ FLOORPLAN
[Floorplan image from Rightmove/Zoopla listing — only shown if external link provided]

---

### 💰 VALUATION
[Market value, reinstatement value, valuation conditions]

---

### 🏗️ CONSTRUCTION & EXTERNAL
[Table of construction elements with condition ratings]

---

### 🔧 INTERNAL & FINISHES
[Table of internal elements]

---

### ⚠️ REPAIRS NEEDED (Category 2/3)
[List all Category 2 and 3 issues with estimated costs and urgency]

---

### 📊 CONDITION ASSESSMENT
[Full condition table with all category ratings]

---

### ⚡ ENERGY PERFORMANCE
[EPC ratings table, current vs potential, recommended improvements with costs]

---

### 📐 ROOM DIMENSIONS
[Table: room name | original dimensions (e.g. 12ft x 10ft) | converted to m² — only shown if dimensions are available from the home report or external listing]

---

### 📍 LOCATION RESEARCH
[Supermarkets, Schools, Commuting, Crime, Lifestyle — each in its own subsection]

---

### 🏷️ SOLD PROPERTIES (Rightmove)
[View all sold properties on Rightmove →](https://www.rightmove.co.uk/house-prices/[POSTCODE].html) — link opens in new tab

[Sold properties at the same postcode — each address is a Rightmove link (opens in new tab), sale price, sale date, property type, bedrooms — sorted newest first, last 3 years only]

---

### ⚖️ LEGAL & CONVEYANCER MATTERS
[Legal notes, solicitor checks, title matters]

---

### 📌 MORTGAGE VALUATION SUMMARY
[Mortgage valuation key points]

---

### 🔍 WHAT COULD BREAK / BUYER NOTES
[Key risks and things to investigate before purchase]

---

### 📊 MARKET CONTEXT
[Market context and valuation commentary]
```

**Output:** Display the full markdown report in the conversation. Also write it to:
- `./home-reports/<pdf-name>/report.md`

Then proceed immediately to Step 8 to generate the HTML (auto-generated on every run).

### Step 8: HTML Report (Auto-Generated)

**HTML is generated automatically on every run** — no user request needed. Both default and red flag modes produce HTML output.

**Location:** `./home-reports/<pdf-name-without-extension>/<pdf-name-without-extension>.html`

**Red flag HTML:** If red flag mode was used, generate a condensed HTML version using the same template but populated only with the red flag sections (Urgent Issues, Plan Ahead, ⚡ Energy & Warmth, Deal Breakers, Positives, Location Snapshot). Do not include the full property summary or other default-mode-only sections.

**Trigger for regeneration:** If the user explicitly asks to regenerate or re-export the HTML (phrases: "regenerate html", "save as html", "export to html", "make html report", "html version", "update html"), regenerate the HTML applying any extra details or customizations the user specifies.

**HTML template file:** `references/report.html` — read this file before generating the HTML. Use it as the base template, replacing all `[PLACEHOLDER]` sections with the corresponding data from the report. Do not leave any placeholder text — fill in the actual data from the PDF.

## Report Structure Details

### PROPERTY SUMMARY Table Format

| Field | Value |
|-------|-------|
| Address | [Full address] |
| Property Type | [End-terrace / Detached / etc.] |
| Size | [m²] |
| Bedrooms | [number] |
| Bathrooms | [number] |
| Built | [Year / Circa year] |
| Council Tax Band | [A-G] — check the Property Questionnaire section of the PDF (separate from Single Survey) for the confirmed band |
| EPC Rating | [Band (number)] — Energy / [Band (number)] — Environmental |
| Asking Price | £[Asking price from Rightmove/Zoopla — only if external link provided] |
| Home Valuation | £[Market value] |
| Heating | [Type] — [Fuel] — [Boiler model + year] |
| Electricity | [Mains/Private] — Last tested: [year] |
| Gas | [Mains/Private] |
| Strong Points | [Bullet list] |
| Weak Points | [Bullet list] |
| External Link | [ZOOPLA / RIGHTMOVE URL if provided by user] |

### Category 2/3 Repair Section Format

For each Category 2 or 3 item:
```
[Element Name]
Category: [2 or 3]
Issue: [Description of the problem]
Estimated Cost: £[min] – £[max]
Urgency: [NOW / SOON]
Recommendation: [What to do]
```

**Total Estimated Cost:** Sum all individual repair cost ranges (using mid-points) to produce a total estimate: `£[min–max total] (mid-point: £[mid-point total])`. Display this at the end of the Repairs Needed section.

## Dependencies

- `pdf-mcp` — For reading PDF content (via ToolSearch for pdf_info, pdf_read_all, pdf_search)
- `WebSearch` (built-in) — **Primary** tool for location research; use first
- `mcp__MiniMax__web_search` — **Fallback** only if WebSearch is unavailable or fails
- `mcp__MiniMax__understand_image` — For analyzing floorplan images to extract room dimensions
- `curl` — For downloading PDFs from URLs (fallback if WebFetch fails)
- Node.js or Python — For HTML generation

## File Paths and Storage

```
home-reports/
└── <pdf-name-without-extension>/
    ├── <original-filename>.pdf  (the downloaded/input PDF)
    ├── <pdf-name>.html         (HTML report)
    ├── report.md               (saved report markdown)
    └── property-link.txt       (saved external listing URL — Zoopla/Rightmove)
```

All generated reports are displayed in the conversation AND saved to disk.