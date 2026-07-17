---
name: readme.md
description: Create or update a README.md file for a project. Triggers on "create a readme", "update the readme", "write a README", or when starting a new project with no README. Uses parallel research agents to investigate each section of the codebase and synthesizes an accurate README covering all standard sections. Use whenever the end goal is a README.md file.
---

# readme.md — README Creation & Update Skill

## Overview

Creates or overhauls a `README.md` by gathering project facts, spawning parallel research agents, then synthesizing an accurate README. Works for any language or framework.

## Workflow

### Step 0 — Project type, size, and basics

**Detect type** — check for these files (first match wins):
- `package.json` → Node.js
- `requirements.txt`, `pyproject.toml`, `Pipfile` → Python
- `go.mod` → Go
- `Cargo.toml` → Rust
- `pom.xml`, `build.gradle` → Java/Kotlin
- `*.csproj` → C#

**Check size** — count source files excluding `node_modules/`, `__pycache__/`, `.git/`, `.venv/`, `venv/`, `dist/`, `build/`, `target/`, `.idea/`, `.vscode/`, `*.log`. If ≤10 files, use the fast-path instead.

**Extract basics** (read directly, no agent needed):
- Name from `package.json` / `pyproject.toml` / etc.
- Package manager and install/start scripts from the same file
- Description from the same file or the main entry point comment
- Env vars from `.env.example` or the main entry point
- Existing `README.md` for reference (if updating, not creating fresh)

### Fast-path (≤10 source files)

Skip agents. Read the files directly, then write a concise README:

```markdown
# [Project Name]

[One-line description]

## Setup

```bash
[install command]
[start command]
```

## What it does

[2-3 sentences inferred from the source files]

## Project structure

```
[file tree, verified]
```

## [Any additional sections as relevant: Database, API, Environment variables]

## License

MIT

## Creator

[Name] — [GitHub profile or contact link]
```

### Phase 1 — Research (parallel agents)

Spawn 4 agents simultaneously:

**Agent B — Structure**
- List the project root to discover top-level directories and files
- Recursively list each subdirectory to discover the full tree, **excluding**: `node_modules/`, `__pycache__/`, `.git/`, `.venv/`, `venv/`, `dist/`, `build/`, `target/`, `.idea/`, `.vscode/`, `*.log`
- Read key files to understand what each directory does (e.g., service files, route files, public assets)
- Determine: accurate project structure tree, directory responsibilities
- For non-JS projects, map common directory names to equivalents: `services/` → `app/`, `routes/` → `endpoints/`, `utils/` → `helpers/`, `public/` → `static/` or `assets/`

**Agent C — API Routes**
- Discover route/handler files by listing directories or searching for patterns like `router`, `route`, `app.get`, `app.post`, `@app.route`, `router.get`, `http.Method`, `handlers`, `controllers`
- Read each route file fully
- Enumerate every endpoint: exact path, HTTP method, query params, request/response shape, what it does
- Flag any undocumented endpoints found in code but not in existing README

**Agent D — Database**
- Discover schema/migration files by searching for `CREATE TABLE`, `sequelize`, `prisma`, `sqlalchemy`, `typeorm`, `db`, `migrations`, `schema`
- Read each schema/migration file fully
- Enumerate every table: name, all columns with types, constraints, indexes
- Describe what each table is for based on its contents

**Agent E — Settings / Config**
- Discover config files by searching for `config`, `settings`, `env`, `.env`, `options`, `defaults`
- Read each config file fully
- Enumerate every settings key: name, default value, where it's used in code, what it controls
- Include env vars read directly in code (`process.env.X`, `os.environ.get('X')`)

### Phase 2 — Synthesis

After all agents return, synthesize findings into `README.md` using the template matching the detected project type.

**Important:** Every section of the template must be populated with findings from the agents. Do not leave any section as a placeholder `[...]` — if an agent did not return data for a section, infer it from the project files directly or flag it as "Not applicable" rather than leaving it blank. The README must be fully filled out, not partially complete.

### Node.js / Express / Vue / React template

```markdown
# [Project Name]

[One-line description]

## Setup

```bash
pnpm install  # (or npm install / yarn install)
pnpm start   # (or npm start / yarn start)
```

Open [http://localhost:PORT](http://localhost:PORT).

## What it does

[Table only if the app monitors or manages distinct resource types:]
| Resource | What it checks/does |
|----------|---------------------|
| [Resource 1] | [Description] |

[Otherwise prose in 2-4 sentences]

## Project structure

```
[project-name]/
[Accurate tree — verify every file actually exists]
```

## Database

[DB engine and file location]

Key tables:
- `table1` — [description]
- `table2` — [description]

## Settings

[How settings are stored — flat columns vs JSON groups]

| Group | Key | Description |
|-------|-----|-------------|
| ... | ... | ... |

## Environment variables

| Variable | Default | Description |
|----------|---------|-------------|
| `PORT` | `3000` | Server port |
| ... | ... | ... |

## API

### [Section name]
- `METHOD /api/path` — description

## License

MIT

## Creator

[Name] — [GitHub profile or contact link]
```

### Python / Django / Flask template

```markdown
# [Project Name]

[One-line description]

## Setup

```bash
uv pip install -r requirements.txt
uv run python manage.py runserver
```

## What it does

[Description]

## Project structure

```
[project-name]/
[Accurate tree]
```

## Database

[DB engine, e.g. PostgreSQL, SQLite with django.db or SQLAlchemy]

Key models/tables:
- `Model1` — [description]
- `Model2` — [description]

## Environment variables

| Variable | Default | Description |
|----------|---------|-------------|
| `DATABASE_URL` | — | PostgreSQL connection string |
| `SECRET_KEY` | — | Django secret key |
| ... | ... | ... |

## License

MIT

## Creator

[Name] — [GitHub profile or contact link]
```

### Go / Rust / Java / other language template

Adapt the Python template — replace package manager, run commands, and DB/ORM terminology with the equivalent for that language ecosystem.

## Rules

1. **Verify before documenting** — never document a file, endpoint, table, or setting that doesn't exist. Flag uncertain items.
2. **Match the project type** — use the template for the detected language/framework. Adjust section names to fit the ecosystem (e.g., "Models" for Django, "Endpoints" for Go).
3. **Be accurate on specifics** — HTTP methods, query params, JSON shapes, column names must match code exactly.
4. **No placeholder text** — replace all `[...]` with real values from the codebase.
5. **Use the actual project name** from `package.json` / `pyproject.toml` / etc., not "My Project".
6. **Completeness** — add sections for notifications, auth, background jobs, or other notable features present in the codebase.

## Output

Write the final `README.md` to the project root. If a `README.md` already exists, replace it entirely — do not preserve outdated content.
