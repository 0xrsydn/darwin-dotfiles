# OpenAI server compaction

A vendored Pi extension that uses OpenAI's Responses compaction protocol for GPT
models while preserving Pi's session, tree, and fallback behavior.

This fork is based on
[`algal/pi-openai-server-compaction`](https://github.com/algal/pi-openai-server-compaction)
and retains its MIT license. It is adapted for this dotfiles repository and Pi
0.82.

## Scope

Remote compaction is intentionally limited to GPT models on these native Pi
providers:

- `openai/*` using `openai-responses`
- `openai-codex/*` using `openai-codex-responses`

Other models and providers are untouched and continue using Pi's default
compaction.

## Compaction behavior

Pi remains responsible for deciding when to compact, selecting the cut point,
and writing the compaction entry. On `session_before_compact`, this extension:

1. asks OpenAI for an opaque `compaction` item through the Responses API;
2. generates a portable text summary in parallel;
3. stores the opaque replacement history in
   `CompactionEntry.details.remoteCompaction`; and
4. replays that history on later requests to the exact same provider/API/model.

If remote compaction fails but the portable summary succeeds, Pi uses that text
summary. If neither extension path succeeds, the handler returns control to
Pi's default compactor.

The opaque artifact is model-specific. Switching models uses Pi's portable text
summary; switching back reconstructs the matching artifact from session JSONL.

## Pi 0.82 adaptation

Unlike upstream, this fork does not override Pi's OpenAI provider or install a
custom WebSocket transport. It uses Pi 0.82's native HTTP Responses transport.
This avoids the upstream WebSocket partial-rendering issue and removes the
runtime `ws` dependency.

Because Pi's full replay payload is not safe to combine with
`previous_response_id`, this fork disables that optimization. It also leaves
normal pre-compaction requests unchanged instead of enabling OpenAI's automatic
`context_management`, whose compaction stream events Pi 0.82 does not natively
persist. Pi triggers compaction normally; post-compaction requests replay the
opaque artifact explicitly.

## Data handling

Conversation context is sent to OpenAI during compaction with `store: false`,
and returned encrypted artifacts are stored in Pi's local session JSONL. The
artifacts are not human-readable. OpenAI's normal API data-handling and abuse
monitoring policies still apply.

## Configuration

Configuration is read from:

- `~/.pi/agent/openai-server-compaction.json`
- `.pi/openai-server-compaction.json` (takes precedence)

```json
{
  "enabled": true,
  "notify": false
}
```

Environment overrides:

- `PI_OPENAI_SERVER_COMPACTION_ENABLED`
- `PI_OPENAI_SERVER_COMPACTION_NOTIFY`

Set `PI_OPENAI_SERVER_COMPACTION_ENABLED=0` for a quick rollback, or start Pi
with `--no-extensions` to bypass all extensions.
