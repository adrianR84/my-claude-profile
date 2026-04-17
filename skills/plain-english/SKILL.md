---
name: plain-english
description: Explain complex topics in simple, plain terms. Use this skill whenever the user asks to "explain like I'm 5", wants something explained "simply", "in plain English", "in layman's terms", or provides a URL/text and asks for an easy-to-understand explanation. Supports three levels: "simple" (plain explanation, default), "age 10" (pre-teen, analogies), and "age 15" (teenager, more depth and nuance). Perfect for breaking down technical concepts, documentation, code, APIs, or any confusing subject.
---

# Plain English — Explain Anything Simply

This skill transforms complex content into simple, accessible explanations. It has three levels and automatically detects which to use based on your phrasing.

## Explanation Levels

| Level | Trigger phrases | Approach |
|-------|----------------|----------|
| **Simple** (default) | "plain english", "simple", "layman's terms", "easy to understand" | Clean plain-English paragraph, no jargon, no technical terms |
| **Age 10** | "age 10", "10 year old", "ten year old" | Pre-teen friendly, vivid analogies from school/sports/games |
| **Age 15** | "age 15", "15 year old", "like a teenager" | Teenager tone, can introduce nuance and trade-offs |

**Default:** If no level is detected, use **Simple**.

## How to use

When the user asks for a simple explanation, follow these steps:

### Step 1 — Detect or set the level

**Explicit override** (takes priority):
- "age 10", "10 year old" → Age 10
- "age 15", "15 year old" → Age 15
- "plain english", "simple", "layman's terms", "easy to understand" → Simple

**Automatic inference** (when no explicit level):
- No special phrases detected → **Simple** (default)

### Step 2 — Get the content
- **URL**: Use `WebFetch` to get the content
- **Text**: Use the text directly from the conversation
- **Code/technical**: Read the file first, then explain

### Step 3 — Apply the level template

#### Simple template (default)
```
## [Topic] — explained simply

[2-3 sentences — what this is in plain English, no jargon]

[2-3 sentences — the core idea, why it matters, what problem it solves]

[One sentence — the short version if someone asked you at a party]
```

**Rules:**
- Plain English only — if a word sounds technical, replace it or define it inline
- No jargon, no acronyms unless briefly explained
- Max 3 short paragraphs
- Short to medium sentences
- Read it back — if a non-technical adult can't follow it, simplify further

#### Age 10 template
```
## [Topic] explained simply

[2-3 sentences — what this is in plain terms]

[Analogy section — paint a picture with something familiar to a 10-year-old]

[One-liner summary — so basically...]
```

**Rules:**
- Max 3 short paragraphs
- Short sentences (can be compound with "and", "but")
- No jargon — every technical term gets replaced or defined
- Analogies: school projects, sports teams, video games, sibling dynamics, cooking
- Can use light cause-effect ("if X then Y")

#### Age 15 template
```
## [Topic] — explained

[Short intro paragraph — what this is and why it matters]

[Body — key ideas with concrete analogies, 2-4 sentences]

[Wrap-up — what this means in practice, one sentence]
```

**Rules:**
- 3-4 paragraphs max
- Can use slightly longer sentences
- Technical terms are OK if briefly defined in plain terms first
- Analogies: social dynamics, technology they use, real-world systems
- Can introduce trade-offs ("the problem with X is Y, but Z helps")
- Can mention consequences and stakes

### Step 4 — Write the explanation

**General rules for all levels:**
- Pick ONE core concept — don't try to explain everything
- Write the analogy first in your head, then explain what's being compared
- Don't use filler words: "essentially", "basically", "importantly", "interestingly"
- Don't use emojis unless asked
- Don't say "in conclusion", "to summarize", "the bottom line is"

**Analogy formula:** "[thing to explain] is like [familiar thing] because [the shared property]."

## Examples

### Simple — Docker
> **Docker — explained simply**
>
> Docker is a tool that lets developers package up a program with everything it needs to run — the code, the tools, the settings — into a single box. That box can then run on any computer, anywhere.
>
> The main benefit is consistency: if it works on your laptop, it'll work on a server in the cloud. It also makes it easy to run multiple isolated versions of the same app on the same machine without them interfering.

### Age 10 — Docker
> **Docker explained simply**
>
> Imagine you built an awesome treehouse with electricity, wifi, your favorite games, and snacks. You want to show it to a friend, but their backyard is different.
>
> Docker is like packing your entire treehouse into a magic box. You can set it up in any backyard, and it'll look and work exactly the same.
>
> So basically: it's a way to package up a complete working computer setup and run it anywhere.

### Age 15 — Docker
> **Docker explained**
>
> Docker lets developers package an application with everything it needs to run — the code, the tools, the settings — into a single portable unit called a container. Think of it like a moving truck for software: instead of hoping your app works on the new computer's setup, you bring the whole environment with you.
>
> The big benefit is consistency: if it works on your laptop, it'll work on a server in the cloud. It also makes it easy to run multiple isolated versions of the same app on the same machine without them interfering with each other.

## What to avoid (all levels)

- Don't explain every feature — focus on ONE core concept
- Don't let analogies break down — if the comparison doesn't hold, find a new one
- Don't oversimplify until it's wrong
- Don't use scare quotes or hedging ("kind of", "sort of", "maybe")
