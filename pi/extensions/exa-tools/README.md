# pi exa-tools scaffold

Global pi extension that adds Exa-backed retrieval tools.

## Tools

- `exa_search` — general web/docs/reference search
- `exa_code` — coding context and open-source implementation examples

## Mental model

- use `exa_search` for official docs, release notes, blog posts, issues, comparisons, and general web research
- use `exa_code` for library usage, framework patterns, API examples, and code-specific prior art

## Credentials

The extension looks for credentials in this order:

1. `EXA_API_KEY`
2. `~/.config/secrets/exa-api-key`
3. `~/.config/secrets/exa_api_key`

If none are found, the tools throw a helpful error.

Note: the Exa account also needs available credits. A valid key with no remaining credits will still fail at request time.

## Command

- `/exa-tools` — show credential status and available tools

## Installation

This repo deploys the extension declaratively through Home Manager to:

```text
~/.pi/agent/extensions/exa-tools
```

## Example usage

General web research:

```text
Use exa_search to find the official docs for Exa context search
```

Coding context:

```text
Use exa_code to find examples of React hook state management patterns
```

Subagent usage:

The `librarian` subagent can use these tools once the extension is globally installed.
