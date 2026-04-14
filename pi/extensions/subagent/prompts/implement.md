---
description: Scout gathers context, planner creates a plan, implementer applies it
---
Use the `subagent` tool with `chain` mode for this workflow:

1. Run `scout` to gather the most relevant code paths for: $@
2. Run `planner` to turn the findings into an implementation plan for: $@
3. Run `implementer` to execute the plan from the previous step using `{previous}`

Use a chain so each step receives the prior step's output via `{previous}`.
