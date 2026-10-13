import type { Model, ModelThinkingLevel, ThinkingLevelMap } from "@earendil-works/pi-ai";

export const PROVIDER_ID = "cursor";
export const THINKING_LEVELS: ModelThinkingLevel[] = ["off", "minimal", "low", "medium", "high", "xhigh", "max"];

function record(value: unknown): value is Record<string, unknown> {
  return typeof value === "object" && value !== null && !Array.isArray(value);
}

function positiveInteger(value: unknown): value is number {
  return typeof value === "number" && Number.isSafeInteger(value) && value > 0;
}

function rate(value: unknown): value is number {
  return typeof value === "number" && Number.isFinite(value) && value >= 0;
}

function modelId(value: unknown): value is string {
  return typeof value === "string" && /^[A-Za-z0-9][A-Za-z0-9._:-]{0,255}$/.test(value);
}

function modalities(value: unknown): ("text" | "image")[] {
  if (!Array.isArray(value)) return [];
  const result: ("text" | "image")[] = [];
  for (const item of value) {
    if ((item === "text" || item === "image") && !result.includes(item)) result.push(item);
  }
  return result;
}

function thinkingLevel(value: unknown): ModelThinkingLevel | undefined {
  switch (value) {
    case "off": case "minimal": case "low": case "medium": case "high": case "xhigh": case "max": return value;
    default: return undefined;
  }
}

type GatewayCursorRow = {
  id: string;
  name: string | undefined;
  input: Model<"openai-completions">["input"];
  contextWindow: number | undefined;
  maxTokens: number | undefined;
};

/** Reject accidental connections to a gateway backed by a shared credential vault. */
export function assertCursorOnlyCatalog(payload: unknown): void {
  if (!record(payload) || !Array.isArray(payload.data)) throw new Error("OMP gateway returned an invalid model catalog.");
  if (payload.data.some(row => !record(row) || row.owned_by !== PROVIDER_ID ||
      typeof row.id !== "string" || !row.id.startsWith(`${PROVIDER_ID}/`))) {
    throw new Error("OMP gateway exposes non-Cursor models. Use the dedicated .omp-cursor configuration.");
  }
}

export function gatewayCursorRows(payload: unknown): GatewayCursorRow[] {
  if (!record(payload) || !Array.isArray(payload.data)) throw new Error("OMP gateway returned an invalid model catalog.");
  const rows: GatewayCursorRow[] = [];
  for (const row of payload.data) {
    if (!record(row) || row.owned_by !== PROVIDER_ID || typeof row.id !== "string" ||
        !row.id.startsWith(`${PROVIDER_ID}/`) || (row.kind !== undefined && row.kind !== "chat") ||
        row.supports_tools === false) continue;
    const id = row.id.slice(PROVIDER_ID.length + 1);
    if (!modelId(id)) continue;
    rows.push({
      id,
      name: typeof row.display_name === "string" ? row.display_name : undefined,
      input: modalities(row.input_modalities),
      contextWindow: positiveInteger(row.context_length) ? row.context_length : undefined,
      maxTokens: positiveInteger(row.max_output_tokens) ? row.max_output_tokens : undefined,
    });
  }
  return rows;
}

/** Join the gateway's routable models with OMP's pricing and thinking metadata. */
export function discoverCursorModels(gateway: unknown, local: unknown, baseUrl: string): Model<"openai-completions">[] {
  const rows = gatewayCursorRows(gateway);
  if (!record(local) || !Array.isArray(local.models)) throw new Error("OMP CLI returned an invalid model catalog.");
  const metadata = new Map<string, Record<string, unknown>>();
  for (const row of local.models) {
    if (record(row) && row.provider === PROVIDER_ID && modelId(row.id) && (row.kind === undefined || row.kind === "chat")) {
      metadata.set(row.id, row);
    }
  }
  const models = new Map<string, Model<"openai-completions">>();
  for (const row of rows) {
    const id = row.id;
    const meta = metadata.get(id);
    if (!meta) continue;
    const cost = meta.cost;
    if (!record(cost) || !rate(cost.input) || !rate(cost.output) || !rate(cost.cacheRead) || !rate(cost.cacheWrite)) {
      throw new Error(`OMP model ${id} has invalid pricing metadata.`);
    }
    if (!positiveInteger(meta.contextWindow) || !positiveInteger(meta.maxTokens) || typeof meta.reasoning !== "boolean") {
      throw new Error(`OMP model ${id} has invalid capability metadata.`);
    }
    const localInput = modalities(meta.input);
    const input = row.input.filter(item => localInput.includes(item));
    if (!input.includes("text")) throw new Error(`OMP model ${id} does not declare text input.`);
    const thinkingLevelMap: ThinkingLevelMap = {};
    const supported = new Set<ModelThinkingLevel>();
    if (Array.isArray(meta.thinking)) {
      for (const item of meta.thinking) {
        const level = thinkingLevel(item);
        if (level) supported.add(level);
      }
    }
    if (meta.reasoning && supported.size === 0) throw new Error(`OMP model ${id} has no thinking-level metadata.`);
    for (const level of THINKING_LEVELS) thinkingLevelMap[level] = supported.has(level) ? level : null;
    const name = row.name ?? (typeof meta.name === "string" ? meta.name : id);
    models.set(id, {
      id, provider: PROVIDER_ID, name: name.replace(/[\u0000-\u001f\u007f-\u009f]/g, ""),
      api: "openai-completions", baseUrl, input,
      reasoning: meta.reasoning, thinkingLevelMap,
      contextWindow: row.contextWindow === undefined ? meta.contextWindow : Math.min(row.contextWindow, meta.contextWindow),
      maxTokens: row.maxTokens === undefined ? meta.maxTokens : Math.min(row.maxTokens, meta.maxTokens),
      cost: { input: cost.input, output: cost.output, cacheRead: cost.cacheRead, cacheWrite: cost.cacheWrite },
      compat: { supportsReasoningEffort: true, supportsDeveloperRole: true, supportsStore: false, maxTokensField: "max_tokens" },
    });
  }
  if (rows.length > 0 && models.size === 0) throw new Error("OMP gateway models do not match the local OMP catalog.");
  return [...models.values()];
}

/** Preserve Pi's public model id while routing unambiguously through Cursor. */
export function gatewayPayload(payload: unknown, id: string, sessionId?: string): Record<string, unknown> {
  if (!record(payload) || !modelId(id)) throw new Error("Invalid OMP gateway request payload.");
  return { ...payload, model: `${PROVIDER_ID}/${id}`, ...(sessionId ? { prompt_cache_key: sessionId } : {}) };
}

export function loopbackBaseUrl(value: string): string {
  const url = new URL(value);
  if (!['127.0.0.1', 'localhost', '[::1]'].includes(url.hostname) || !['http:', 'https:'].includes(url.protocol) ||
      url.username || url.password || url.search || url.hash || url.pathname.replace(/\/$/, "") !== "/v1") {
    throw new Error("OMP_GATEWAY_URL must be an authenticated loopback URL ending in /v1.");
  }
  return url.toString().replace(/\/$/, "");
}
