import { execFile } from "node:child_process";
import { readFile, stat } from "node:fs/promises";
import { homedir } from "node:os";
import { join } from "node:path";
import { promisify } from "node:util";
import { createProvider, type ProviderStreams, type StreamOptions } from "@earendil-works/pi-ai";
import { openAICompletionsApi } from "@earendil-works/pi-ai/compat";
import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";
import { assertCursorOnlyCatalog, discoverCursorModels, gatewayCursorRows, gatewayPayload, loopbackBaseUrl, PROVIDER_ID } from "./catalog.ts";

const execute = promisify(execFile);
const TIMEOUT_MS = 10_000;

function timeoutSignal(signal?: AbortSignal): AbortSignal {
  const timeout = AbortSignal.timeout(TIMEOUT_MS);
  return signal ? AbortSignal.any([signal, timeout]) : timeout;
}

export default function ompGateway(pi: ExtensionAPI): void {
  const baseUrl = loopbackBaseUrl(process.env.OMP_GATEWAY_URL ?? "http://127.0.0.1:4000/v1");
  const tokenFile = process.env.OMP_GATEWAY_TOKEN_FILE ?? join(homedir(), ".omp-cursor", "auth-gateway.token");
  const omp = process.env.OMP_GATEWAY_COMMAND ?? "omp";
  // Pi exports its own PI_CODING_AGENT_DIR. Never let OMP create its vault there.
  const metadataEnv: NodeJS.ProcessEnv = {
    ...process.env,
    PI_CONFIG_DIR: ".omp-cursor",
    PI_CODING_AGENT_DIR: process.env.OMP_GATEWAY_AGENT_DIR ?? join(homedir(), ".omp-cursor", "agent"),
    OMP_PROFILE: "",
    PI_PROFILE: "",
    PI_CONFIG_FILES: "",
  };
  delete metadataEnv.OMP_AUTH_BROKER_URL;
  delete metadataEnv.OMP_AUTH_BROKER_TOKEN;

  async function token(): Promise<string | undefined> {
    try {
      const info = await stat(tokenFile);
      if (!info.isFile() || (info.mode & 0o077) !== 0) throw new Error("OMP gateway token file must have owner-only permissions.");
      const key = (await readFile(tokenFile, "utf8")).trim();
      if (!key || /\s/.test(key)) throw new Error("OMP gateway token file is empty or invalid.");
      return key;
    } catch (error) {
      if (error instanceof Error && "code" in error && error.code === "ENOENT") return undefined;
      throw error;
    }
  }

  async function catalog(signal?: AbortSignal): Promise<unknown> {
    const key = await token();
    if (!key) throw new Error("OMP gateway token is missing. Start the managed OMP services first.");
    let response: Response;
    try {
      response = await fetch(`${baseUrl}/models`, {
        headers: { Authorization: `Bearer ${key}` }, signal: timeoutSignal(signal), redirect: "error",
      });
    } catch {
      signal?.throwIfAborted();
      throw new Error("OMP gateway is unavailable. Check the local omp-auth-broker and omp-auth-gateway services.");
    }
    if (!response.ok) throw new Error(`OMP gateway model discovery failed with HTTP ${response.status}.`);
    let payload: unknown;
    try { payload = await response.json(); }
    catch { throw new Error("OMP gateway returned invalid model JSON."); }
    assertCursorOnlyCatalog(payload);
    return payload;
  }

  // Keep Pi's streaming, tools, abort handling, and usage accounting. Only qualify
  // the wire model id and carry the Pi session id into OMP's conversation cache.
  const supportedApi = openAICompletionsApi();
  function optionsForGateway(options?: StreamOptions): StreamOptions {
    return {
      ...options,
      onPayload: async (payload, model) => {
        const routed = gatewayPayload(payload, model.id, options?.sessionId);
        const replacement = await options?.onPayload?.(routed, model);
        return gatewayPayload(replacement ?? routed, model.id, options?.sessionId);
      },
    };
  }
  const api: ProviderStreams = {
    stream: (model, context, options) => supportedApi.stream(model, context, optionsForGateway(options)),
    streamSimple: (model, context, options) => supportedApi.streamSimple(model, context, optionsForGateway(options)),
  };
  const provider = createProvider({
    id: PROVIDER_ID,
    name: "Cursor through OMP",
    baseUrl,
    models: [],
    api,
    auth: {
      apiKey: {
        name: "OMP gateway token file",
        check: async () => (await token()) ? { type: "api_key", source: "OMP gateway token file" } : undefined,
        resolve: async ({ signal }) => {
          signal.throwIfAborted();
          const key = await token();
          return key ? { auth: { apiKey: key, baseUrl }, source: "OMP gateway token file" } : undefined;
        },
      },
    },
    fetchModels: async context => {
      const signal = timeoutSignal(context.signal);
      const gateway = await catalog(signal);
      let stdout: string;
      try {
        ({ stdout } = await execute(omp, ["models", "cursor", "--json", "--no-extensions"], {
          signal, timeout: TIMEOUT_MS, maxBuffer: 8 * 1024 * 1024, env: metadataEnv,
        }));
      } catch {
        context.signal.throwIfAborted();
        // execFile errors include child stderr. Never forward those bytes to Pi.
        throw new Error("Cannot read OMP model metadata. Check OMP_GATEWAY_COMMAND and the dedicated Cursor configuration.");
      }
      let metadata: unknown;
      try { metadata = JSON.parse(stdout); }
      catch { throw new Error("OMP CLI returned invalid model JSON."); }
      return discoverCursorModels(gateway, metadata, baseUrl);
    },
  });
  pi.registerProvider(provider);

  pi.registerCommand("omp-gateway", {
    description: "Check the OMP gateway or refresh Cursor models: /omp-gateway status|refresh",
    handler: async (args, ctx) => {
      try {
        const action = args.trim() || "status";
        if (action === "refresh") {
          const result = await ctx.modelRegistry.refresh({ providers: [PROVIDER_ID], allowNetwork: true, force: true });
          const error = result.errors.get(PROVIDER_ID);
          if (error) throw error;
          if (result.aborted) throw new Error("OMP gateway model refresh was cancelled.");
          const count = ctx.modelRegistry.getAll().filter(model => model.provider === PROVIDER_ID).length;
          ctx.ui.notify(`OMP gateway refreshed ${count} Cursor models. Select one with /model.`, "info");
        } else if (action === "status") {
          const count = gatewayCursorRows(await catalog()).length;
          ctx.ui.notify(`OMP gateway connected at ${baseUrl}. ${count} Cursor chat models are routable.`, "info");
        } else {
          ctx.ui.notify("Usage: /omp-gateway status|refresh", "warning");
        }
      } catch (error) {
        ctx.ui.notify(error instanceof Error ? error.message : "OMP gateway check failed.", "error");
      }
    },
  });
}
