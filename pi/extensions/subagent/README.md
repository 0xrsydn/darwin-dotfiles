# pi subagent scaffold

Foundation for a global pi subagent extension with parallel and chained delegation.

## What this includes

- `index.ts` — main `subagent` tool and `/subagents` command
- `agents.ts` — agent discovery and manifest parsing
- `agents/` — starter bundled agents:
  - `scout` → `zai/glm-5.1`
  - `planner` → `openai-codex/gpt-5.4:xhigh`
  - `implementer` → `openai-codex/gpt-5.3-codex`
  - `reviewer` → `openai-codex/gpt-5.4:xhigh`
  - `librarian` → `zai/glm-5.1` + `exa_search` / `exa_code`
- `prompts/` — starter prompt templates:
  - `/implement`
  - `/scout-and-plan`
  - `/implement-and-review`
  - `/parallel-scout`
  - `/research`

## Discovery model

This extension supports three agent sources:

- **bundled** — agents shipped in this directory (`./agents`)
- **user** — `~/.pi/agent/agents`
- **project** — nearest `.pi/agents` from the current working directory upward

Scope values:

- `global` — bundled + user
- `project` — project only
- `both` — bundled + user + project

Precedence when names collide:

1. bundled
2. user
3. project

So project-local agents override user/global ones, and user/global agents override bundled defaults.

## Parallel safety

Parallel mode is intentionally conservative.

- agents with `parallelSafe: true` can run in parallel
- agents with `parallelSafe: false` are blocked in parallel mode

The bundled `implementer` is marked serial-only.

## Agent manifest format

Each agent is a markdown file with YAML frontmatter:

```md
---
name: planner
description: Creates implementation plans
model: anthropic/claude-sonnet-4-5
tools: read, grep, find, ls
parallelSafe: true
role: planner
tags: planning, design
---

System prompt goes here.
```

Notes:

- `model` accepts normal pi `--model` values, including `provider/id` and optional `:thinking`
- the current scaffold intentionally uses built-in pi providers (`openai-codex`, `zai`), so no custom provider extension is required yet
- `tools` should usually be explicit to avoid recursive delegation
- `parallelSafe` defaults to `false` if omitted

## Install globally from this repo

Recommended runtime target:

```bash
mkdir -p ~/.pi/agent/extensions
ln -sfn /Users/rasyidanakbar/Development/dotfiles/pi/extensions/subagent ~/.pi/agent/extensions/subagent
```

Then start pi and run:

```text
/reload
```

Because prompts and bundled agents live inside the extension directory, a single directory symlink is enough.

## Usage examples

Single agent:

```text
Use subagent planner to propose a plan for refactoring auth
```

Parallel:

```text
Use subagent with two tasks in parallel: scout auth flow, librarian find similar patterns
```

Chain:

```text
Use subagent chain: scout -> planner -> implementer
```

Prompt templates:

```text
/implement add request validation to the API
/scout-and-plan refactor auth to support oauth
/implement-and-review add pagination to the endpoint
/parallel-scout investigate session handling
/research evaluate the best pattern for background job retries in this codebase
```

## Good next steps

1. add `parallel_then_reduce`
2. add budget / timeout controls
3. add a custom `index_search` tool for librarian workflows
4. wire the whole `pi/extensions/` directory into Home Manager so `~/.pi/agent/extensions/` is managed automatically
5. pair librarian with the separate `pi/extensions/exa-tools` extension for web/docs/code retrieval
