---
description: Run local scout and external librarian research in parallel, then synthesize grounded guidance
---
Use the `subagent` tool with `tasks` mode to run these in parallel for: $@

- `scout`: inspect the current repository and identify the most relevant local files, entrypoints, constraints, and likely change surface
- `librarian`: gather external references and coding prior art, using `exa_search` for docs/web research and `exa_code` for implementation examples when useful

After both results return:

1. Synthesize them into one grounded response.
2. Clearly separate:
   - local repository findings
   - external references and docs
   - recommended implementation patterns
3. Prefer official docs and high-signal sources over generic summaries.
4. Call out where external advice may not fit this repository's existing architecture.
5. Do **not** implement changes unless the user explicitly asks.

Return the final answer in this structure:

## Goal
## Local Findings
## External References
## Recommended Pattern
## Risks / Caveats
## Next Steps
## Sources
