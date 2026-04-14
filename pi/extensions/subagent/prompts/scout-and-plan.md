---
description: Scout gathers context, planner turns it into a concrete plan without implementation
---
Use the `subagent` tool with `chain` mode for this workflow:

1. Run `scout` to gather the most relevant code paths for: $@
2. Run `planner` to create a concrete implementation plan for: $@ using `{previous}` as context

Return the plan only. Do not implement changes.
