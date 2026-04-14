---
description: Implementer makes the change, reviewer critiques it, implementer applies the review
---
Use the `subagent` tool with `chain` mode for this workflow:

1. Run `implementer` to implement: $@
2. Run `reviewer` to review the implementation output using `{previous}`
3. Run `implementer` again to apply the review feedback using `{previous}`

Use a chain so each step receives the prior step's output via `{previous}`.
