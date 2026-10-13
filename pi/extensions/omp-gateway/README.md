# Cursor through OMP

Use Cursor models in Pi through a local Oh My Pi, or OMP, authentication gateway.
The public model selector is `cursor/grok-4.7`.
This extension registers only Cursor chat models that support tools.
It does not change Pi's default model or any pstack role.

## Cursor-only configuration

The macOS services use a separate configuration directory, `~/.omp-cursor`.
They do not read or copy credentials from `~/.omp/agent/agent.db`.
Log into **only Cursor** in this directory. Do not import your full OMP vault.

OMP 18.8.3 has no broker provider allowlist.
Credential isolation therefore depends on keeping this directory Cursor-only.
Pi also rejects model discovery when a gateway exposes non-Cursor models.
This check is not a server-side authorization rule for other gateway clients.

Both services bind to `127.0.0.1` and require separate bearer tokens.
OMP creates owner-only token files at runtime.
Nix stores token paths, never token contents.

## Setup on macOS

1. Validate the system configuration.

   ```sh
   darwin-rebuild build --dry-run --flake .#macbook-pro
   ```

2. Install the extension and start the managed services.

   ```sh
   sudo darwin-rebuild switch --flake .#macbook-pro
   ```

3. Open a new terminal so Home Manager's environment variables take effect.

4. Log into Cursor in the separate configuration directory.
   This requires a new browser login. Your existing OMP login remains unchanged.

   ```sh
   omp-cursor-login
   ```

5. Wait at least 10 seconds for the gateway's credential poll.
   Start a new Pi session, then refresh the catalog.

   ```text
   /omp-gateway refresh
   /model
   ```

   Select `cursor/grok-4.7` in the model picker.
   Alternatively, start Pi with `pi --model cursor/grok-4.7` after the first refresh.

`omp-cursor-login` sets the isolated directory and calls `omp auth-broker login cursor`.
It clears inherited profile, configuration-overlay, and broker settings.

The extension loads at Pi startup. No skill activation is required.
Its factory does not launch OMP, create sockets, or start background timers.
Launchd manages the broker and gateway separately.

## How it works

```text
Pi native provider: cursor
  -> authenticated local gateway on 127.0.0.1:4000
  -> authenticated local broker on 127.0.0.1:8765
  -> dedicated Cursor OAuth credentials in ~/.omp-cursor/agent/agent.db
  -> Cursor inference service
```

OAuth means Open Authorization. OMP handles browser login and token refresh.
Pi reads only the gateway token file. It does not store Cursor access or refresh tokens.

The extension uses Pi 1.1.0's `createProvider` API.
Pi's OpenAI-compatible chat implementation handles streaming, tool calls, cancellation, and usage accounting.
OMP translates those requests into Cursor's protocol.
The extension sends `cursor/grok-4.7` as the wire model ID to prevent ambiguous routing.
It carries Pi's session ID in `prompt_cache_key` to keep tool results in the same Cursor conversation.

Model discovery joins two sources:

- The authenticated gateway's `/v1/models` response determines routable models.
- `omp models cursor --json --no-extensions` supplies pricing and supported thinking levels.

The extension uses the smaller advertised context and output limits.
It does not guess missing prices or thinking levels.
Reported costs use OMP's base catalog rates, not Cursor subscription billing or long-context pricing tiers.
Pi persists the discovered catalog and restores it offline.
A failed refresh preserves the previous catalog. A successful empty catalog removes Cursor models.
Offline catalog access does not permit offline inference.

## Commands and settings

- `/omp-gateway status` checks the connection and counts Cursor chat models.
- `/omp-gateway refresh` refreshes only Pi's Cursor provider.

The Darwin option `rsydn.ompGateway.enable` controls both services.
Its default is `true`. The module also supports `package`, `brokerPort`, and `gatewayPort`.

Home Manager sets these variables:

| Variable | Default |
| --- | --- |
| `OMP_GATEWAY_URL` | `http://127.0.0.1:4000/v1` |
| `OMP_GATEWAY_TOKEN_FILE` | `~/.omp-cursor/auth-gateway.token` |
| `OMP_GATEWAY_COMMAND` | The configured OMP executable |
| `OMP_GATEWAY_AGENT_DIR` | `~/.omp-cursor/agent` |

The extension accepts only loopback gateway URLs ending in `/v1`.
Embedded credentials, query strings, and remote endpoints are rejected.
The metadata command clears inherited profile, configuration-overlay, and broker settings.
It overrides Pi's agent directory so OMP cannot open a vault inside `~/.pi/agent`.
Do not set these overrides to a shared credential vault or gateway.

For pstack, choose `cursor/grok-4.7` through `/setup-pstack` after discovery.
Existing pstack assignments do not change automatically.

## Troubleshooting

Check the services without printing credentials:

```sh
launchctl print "gui/$(id -u)/com.rsydn.omp-auth-broker"
launchctl print "gui/$(id -u)/com.rsydn.omp-auth-gateway"
```

Service logs are under `~/.omp-cursor/logs`.
Treat authentication diagnostics as private. Do not paste token files or credential snapshots into issues.
A missing token means the corresponding service has not started successfully.
HTTP 401 means the gateway rejected its bearer token.
A mixed-provider catalog means the endpoint does not use the dedicated Cursor configuration.

Login and refresh behavior depend on the configured OMP version.
This implementation does not patch OMP's OAuth flow.
Update the OMP package if Cursor changes that flow; do not work around it by copying other provider credentials.

## Tests

```sh
node --experimental-strip-types --test \
  pi/extensions/omp-gateway/tests/*.test.ts \
  pi/extensions/omp-gateway/tests/*.test.cjs
```

The runtime test starts the installed Pi executable and a local HTTP fixture.
It checks isolated metadata discovery, native streaming, tool execution, thinking levels, usage accounting,
token rotation, mixed-provider rejection, and offline catalog restoration.
A separate test starts real OMP services with an empty temporary vault.
It verifies token permissions, authentication requirements, foreign-model rejection, and default-vault isolation.
These tests do not consume Cursor quota.
Real Cursor inference requires the separate browser login before it can be verified.
