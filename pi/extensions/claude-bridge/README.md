# claude-bridge

Use a Claude Pro/Max subscription from pi through the real Claude Code CLI.

Claude Code performs the inference. Pi keeps the agent loop, the tools, and the
UI. Requests count as Claude Code usage instead of third-party harness usage.

## Why

Pi's built-in Anthropic provider speaks the Messages API directly. Anthropic
treats that as a third-party harness, so a subscription login draws from extra
usage and is billed per token. Requests made by the `claude` binary count as
Claude Code usage. Pi warns about the difference with
`warnings.anthropicExtraUsage` in `/settings`.

## How it works

1. Pi calls `streamSimple` with the transcript and the tool definitions.
2. The extension starts one `claude` process per pi session, with
   `--input-format stream-json --output-format stream-json --tools ""`.
3. Pi's tools are published to Claude Code as a local HTTP MCP server
   (`mcp.ts`). The model may call them, and nothing else.
4. When the model calls a tool, the MCP `tools/call` handler blocks. The
   extension ends the pi turn with `toolUse`.
5. Pi executes the tool, appends the result, and calls `streamSimple` again.
6. The extension resolves the blocked handler. Claude Code continues on the same
   process.
7. For a final text response, Pi waits for the CLI's `result` record. A streamed
   `message_stop` alone does not complete the Pi request.

The extension compares Pi's active transcript with its last completed response.
It restarts Claude Code when history changes or the model, prompt, tools, or
thinking effort changes. After a restart, it sends previous messages as labeled
conversation records before the current request. Previous tool calls are data;
the extension does not execute them again. Historical images remain image blocks.

The blocked handler is what keeps tool execution in pi, so pi's approval
prompts, diff rendering, and snapshots still apply.

## Setup

1. Log in to Claude Code on this machine:

   ```bash
   claude auth login
   claude auth status   # expect authMethod: "claude.ai"
   ```

2. Remove any exported `ANTHROPIC_API_KEY` from the environment Pi runs in. An
   exported key takes precedence over the claude.ai login in ordinary Claude Code
   commands. The bridge strips `ANTHROPIC_API_KEY`,
   `ANTHROPIC_AUTH_TOKEN`, `ANTHROPIC_BASE_URL`, and
   `ANTHROPIC_FOUNDRY_API_KEY` from the child, but other tools that read them are
   unaffected, so removing the export is still the correct fix.

3. Select a model with `/model`, for example `claude-bridge/claude-haiku-5-5`.

Models come from pi-ai's Anthropic catalog, so new Claude models appear after a
pi-ai update. Dated snapshot ids are hidden.

## Tests before a system rebuild

Load the working copy directly. No `darwin-rebuild switch` is required:

```bash
pi --offline --no-extensions --no-mcp \
  -e ./pi/extensions/claude-bridge/index.ts \
  -e builtin:codemode \
  --model claude-bridge/claude-haiku-5-5 \
  --tools read,codemode --no-session
```

Ask Pi to read a file through codemode. Then ask a follow-up question.
The selected tools are read-only. `--no-mcp` disables Pi's configured MCP servers,
not the bridge's local tool server. These requests use your Claude subscription.

Run the offline regression suite with Node.js 22.6 or later and `pi` on `PATH`:

```bash
node --experimental-strip-types --test \
  pi/extensions/claude-bridge/tests/*.test.ts \
  pi/extensions/claude-bridge/tests/*.test.cjs
```

The provider test runs the real Pi runtime with a fake `claude` process.
It makes no model requests and uses temporary files only.

## Verified

Live checks used Claude Code 2.1.293 and `claude-haiku-5-5`:

- Pi codemode with nested tool execution
- concurrent reads, direct multiple-tool responses, and missing-file errors
- recovery after a codemode exception
- immediate follow-up prompts without an artificial pause
- memory across turns and restoration after abort or an effort change
- injected shell output and steering during tool execution
- manual compaction and memory recall with a reduced test retention threshold
- isolation of a new Pi session

Offline tests cover delayed CLI results, late duplicate assistant records,
non-streaming tool responses, provider errors, process exits, steering, model,
prompt, tool, and effort changes, compaction, branch changes, historical image
preservation, and MCP protocol handling.
Authentication was checked with the bridge's API variables removed: `claude.ai`
login with a Pro subscription. These tests do not independently verify billing.

## Deliberate limits

Compared with [pi-claude-bridge](https://github.com/elidickinson/pi-claude-bridge),
this is the small version:

| Limit | Consequence |
| --- | --- |
| One process per Pi session, no Claude Code session files | A restart restores history as labeled records, not the original native transcript |
| Transcript changes require a restart | Compaction, branch changes, and cross-provider history changes can invalidate the CLI prompt cache |
| Model, prompt, tools, or effort changes restart the process | New settings take effect with restored history, but the CLI cache starts again |
| Steering with tool results restarts the process | Pi's results and steering reach Claude together; the original CLI turn is canceled |
| No `AskClaude` tool | Delegate by switching models instead |
| 1M context is not requested | Models use their catalog window, not the `[1m]` form |
| Cost shows zero | The subscription has no per-token price; token counts still show |

## Known risks

- `claudecode/toolUseId` is a Claude Code extension, not part of the MCP
  specification. If it disappears, every tool call fails loudly instead of being
  paired with the wrong result.
- Claude Code's hooks fire in these sessions. Set `PI_CODING_AGENT=true` (the
  bridge already does) and skip the hook when it is set.
- Anthropic's billing rules for Agent SDK tools have changed before. If plan
  usage stops counting, check `claude.ai/settings/usage` before blaming the
  bridge.

## Files

| File | Purpose |
| --- | --- |
| `index.ts` | Provider registration, CLI process, event pump, Pi event emission |
| `mcp.ts` | The HTTP MCP server that bridges Pi's tools to Claude Code |
| `transcript.ts` | History fingerprints and conversation restoration |
| `tests/` | Offline protocol, transcript, and provider regression tests |
