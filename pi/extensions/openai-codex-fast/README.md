# OpenAI Codex fast mode

Adds `/fast` for Pi's `openai-codex` provider and `openai-codex-responses` API.
When enabled, the extension adds `service_tier: "priority"` to matching requests.
It keeps the selected model, reasoning level, tools, and conversation input.

## Usage

- `/fast` toggles fast mode.
- `/fast on` requests priority service. Usage may increase.
- `/fast off` stops this extension's override and restores provider defaults.
- `/fast status` reports the setting without changing it.

New sessions start with fast mode off. Changes are stored as custom session
entries, outside model context. Resume and reload restore the active branch's
setting. Forks inherit only settings before the fork point. Switching to another
provider makes the setting inactive; switching back to Codex reactivates it.
Changes require an idle session. Status reports remain available during a turn.

The footer shows `Codex fast: priority` while this extension requests priority
service. This shows the requested tier, not confirmation from OpenAI.

## Availability and usage

OpenAI controls priority access for each model and account. Priority service can
increase subscription usage or cost. The extension does not change reasoning
settings, query Codex's model catalog, verify account eligibility, or guarantee
faster responses. Unlike the Codex CLI, it does not hide the command for models
without an advertised fast tier. API failures use Pi's normal error handling;
the extension does not silently retry with another tier.

Other providers are untouched, including `openai`, OpenRouter, and providers
that reuse the Codex API under another name. While enabled, this extension
replaces any existing `service_tier` value with `priority`. Disabling it leaves
native request settings and other extensions' overrides unchanged.

Your `openai-server-compaction` extension can remain enabled. Both request
patches preserve unrelated fields. Fast mode applies to normal session requests,
not the compaction extension's separate HTTP compaction or summary calls.

## Installation

Home Manager deploys this directory through `rsydn.aiTools.piExtensions` along
with the other extensions. Apply your usual dotfiles rebuild, then run `/reload`.
To test before deploying:

```sh
pi -e ./pi/extensions/openai-codex-fast/index.ts
```

## Codex implementation reference

Reviewed OpenAI Codex commit
[`1a69ad3237fc`](https://github.com/openai/codex/tree/1a69ad3237fc485273ccfa9731239fdf789b43e4).

- [Service-tier UI](https://github.com/openai/codex/blob/1a69ad3237fc485273ccfa9731239fdf789b43e4/codex-rs/tui/src/chatwidget/service_tiers.rs)
  toggles the model's advertised Fast tier and persists the selection.
- [Model catalog](https://github.com/openai/codex/blob/1a69ad3237fc485273ccfa9731239fdf789b43e4/codex-rs/models-manager/models.json)
  identifies Fast with the request value `priority`.
- [Request builder](https://github.com/openai/codex/blob/1a69ad3237fc485273ccfa9731239fdf789b43e4/codex-rs/core/src/client.rs)
  sends the selected tier in `service_tier`.

Pi's `before_provider_request` hook changes the native payload. No provider
replacement, custom transport, or additional runtime dependency is required.

## Tests

Requires Node.js 22.19 or newer and an installed `pi` executable. Tested with
Pi 1.1.0.

```sh
node --experimental-strip-types --test \
  pi/extensions/openai-codex-fast/tests/*.test.ts \
  pi/extensions/openai-codex-fast/tests/*.test.cjs
```

Unit tests cover scope, payload preservation, branch state, and both compaction
patch orders. The runtime test uses Pi's real loader and native providers with a
local HTTP fixture. It checks outgoing payloads, commands, the idle guard,
provider switching, resume, and forks. It sends no requests to OpenAI and uses no
real credentials.
