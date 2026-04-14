---
description: Run scout and librarian in parallel, then summarize their findings
---
Use the `subagent` tool with `tasks` mode to run these in parallel for: $@

- `scout`: identify the most relevant files, flows, and entrypoints
- `librarian`: find related patterns, prior art, tests, or docs

After both results return, synthesize them into one concise summary with recommended next steps.
