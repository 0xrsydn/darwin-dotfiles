export const FAST_STATE_ENTRY = "openai-codex-fast";

export type FastCommand = "toggle" | "on" | "off" | "status";

type ModelIdentity = { provider: string; api: string; id: string };

export function parseFastCommand(args: string): FastCommand | undefined {
  const command = args.trim().toLowerCase();
  if (command === "") return "toggle";
  if (command === "on" || command === "off" || command === "status") return command;
  return undefined;
}

export function isCodexModel(model: ModelIdentity | undefined): boolean {
  return model?.provider === "openai-codex" && model.api === "openai-codex-responses";
}

export function restoreFastMode(branch: readonly unknown[]): boolean {
  let enabled = false;
  for (const entry of branch) {
    if (
      typeof entry !== "object" || entry === null ||
      !("type" in entry) || entry.type !== "custom" ||
      !("customType" in entry) || entry.customType !== FAST_STATE_ENTRY ||
      !("data" in entry)
    ) continue;
    const data = entry.data;
    if (
      typeof data === "object" && data !== null &&
      "enabled" in data && typeof data.enabled === "boolean"
    ) enabled = data.enabled;
  }
  return enabled;
}

export function patchFastPayload({
  enabled,
  model,
  payload,
}: {
  enabled: boolean;
  model: ModelIdentity | undefined;
  payload: unknown;
}): unknown {
  if (
    !enabled || !isCodexModel(model) ||
    typeof payload !== "object" || payload === null || Array.isArray(payload) ||
    !("model" in payload) || payload.model !== model?.id ||
    !("input" in payload) || !Array.isArray(payload.input)
  ) return undefined;

  return { ...payload, service_tier: "priority" };
}
