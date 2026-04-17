---
name: weather
description: Get weather forecasts using Open-Meteo API via weather-open-meteo-mcp
allowed-tools: Bash(bash *)
---

# Weather Skill

Get current and forecasted weather data using Open-Meteo API.

## Core Workflow

```bash
# List available commands
bash C:/Users/adria/.claude/skills/weather/scripts/weather --list

# Get hourly forecast (next 12 hours)
bash C:/Users/adria/.claude/skills/weather/scripts/weather weather-get-hourly --location "Gillingham"

# Get daily forecast (up to 15 days)
bash C:/Users/adria/.claude/skills/weather/scripts/weather weather-get-daily --location "Gillingham" --days 5
```

## Commands

### weather-get-hourly
Get hourly weather forecast for the next 12 hours.

**Parameters:**
- `--location` - City or location name (e.g., "Gillingham", "London", "Paris")
- `--units` - Temperature units: `metric` (Celsius, default) or `imperial` (Fahrenheit)

### weather-get-daily
Get daily weather forecast for up to 15 days.

**Parameters:**
- `--location` - City or location name
- `--days` - Number of days: 1, 5, 10, or 15 (default: 5)
- `--units` - Temperature units: `metric` or `imperial`

## Before Querying

- **Location format**: Use city name only (e.g., "Gillingham" not "Gillingham, UK"). The MCP server handles geocoding internally.
- **Days selection**: For quick checks use `--days 1`, for planning use `--days 5` or `--days 10`.
- **Units**: Default is metric (Celsius). Use `--units imperial` for Fahrenheit.

## Anti-Patterns & Gotchas

- **Location with country code fails**: `--location "Gillingham, UK"` returns "No location found". Use just the city name.
- **No JSON output**: The MCP server returns human-readable text format, not JSON. There is no `--pretty` flag.
- **npm warnings**: Unknown config warnings about "minimum-release-age" are harmless npm noise.

## Examples

```bash
# Current weather in Gillingham (hourly for next 12 hours)
bash C:/Users/adria/.claude/skills/weather/scripts/weather weather-get-hourly --location "Gillingham"

# 5-day forecast for London in Fahrenheit
bash C:/Users/adria/.claude/skills/weather/scripts/weather weather-get-daily --location "London" --days 5 --units imperial

# 15-day forecast for Paris
bash C:/Users/adria/.claude/skills/weather/scripts/weather weather-get-daily --location "Paris" --days 15
```
