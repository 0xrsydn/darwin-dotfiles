/**
 * OpenAI API and OpenAI Codex model/payload helpers.
 *
 * Keeps provider-specific detection, request patching, endpoint classification,
 * and model-key logic out of the higher-level extension wiring.
 */
import type { JsonRecord } from "./config.ts";
import type { ResponsesReasoningConfig, ResponsesTextConfig } from "./remote-compaction.ts";
import { isRecord } from "./config.ts";

export type ModelLike = {
  api?: unknown;
  provider?: unknown;
  id?: unknown;
  baseUrl?: unknown;
  reasoning?: unknown;
  input?: readonly unknown[];
};

export function hostnameFromBaseUrl(baseUrl: unknown): string | undefined {
  if (typeof baseUrl !== "string" || !baseUrl.trim()) return undefined;
  try {
    return new URL(baseUrl).hostname.toLowerCase();
  } catch {
    return undefined;
  }
}

export function isOpenAIResponsesModel(model: unknown): model is ModelLike {
  return (
    isRecord(model) &&
    (
      model.api === "openai-responses" ||
      model.api === "openai-codex-responses"
    )
  );
}

export function isDirectOpenAIResponsesModel(model: ModelLike): boolean {
  if (model.api !== "openai-responses") return false;
  if (model.provider !== "openai") return false;
  const host = hostnameFromBaseUrl(model.baseUrl);
  return host === undefined || host === "api.openai.com";
}

export function isOpenAICodexResponsesModel(model: ModelLike): boolean {
  if (model.api !== "openai-codex-responses") return false;
  const provider = typeof model.provider === "string" ? model.provider : "";
  if (provider === "openai-codex") return true;
  const host = hostnameFromBaseUrl(model.baseUrl);
  return host === "chatgpt.com";
}

function isGptModel(model: ModelLike): boolean {
  return typeof model.id === "string" && model.id.startsWith("gpt-");
}

export function supportsRemoteCompactionModel(model: unknown): model is ModelLike {
  if (!isOpenAIResponsesModel(model) || !isGptModel(model)) return false;
  return isDirectOpenAIResponsesModel(model) || isOpenAICodexResponsesModel(model);
}

export function looksLikeResponsesPayload(payload: JsonRecord): boolean {
  return "input" in payload || "model" in payload || "messages" in payload;
}

export function modelKey(model: ModelLike): string {
  return `${String(model.provider)}:${String(model.api)}:${String(model.id)}`;
}

export function thinkingLevelToResponsesReasoning(
  thinkingLevel: unknown,
): ResponsesReasoningConfig | undefined {
  if (thinkingLevel === "minimal") return { effort: "minimal", summary: "auto" };
  if (thinkingLevel === "low") return { effort: "low", summary: "auto" };
  if (thinkingLevel === "medium") return { effort: "medium", summary: "auto" };
  if (thinkingLevel === "high") return { effort: "high", summary: "auto" };
  if (thinkingLevel === "xhigh") return { effort: "xhigh", summary: "auto" };
  return undefined;
}

export function applyRemoteHistoryPayloadPatch(params: {
  payload: JsonRecord;
  explicitHistory: unknown[];
}): JsonRecord {
  const nextPayload: JsonRecord = {
    ...params.payload,
    input: params.explicitHistory,
  };
  delete nextPayload.messages;
  delete nextPayload.previous_response_id;
  return nextPayload;
}

export function extractResponsesReasoningConfig(payload: unknown): ResponsesReasoningConfig | undefined {
  if (!isRecord(payload) || !isRecord(payload.reasoning)) return undefined;
  const effort = payload.reasoning.effort;
  const summary = payload.reasoning.summary;
  const normalized: ResponsesReasoningConfig = {
    ...(typeof effort === "string" ? { effort: effort as ResponsesReasoningConfig["effort"] } : {}),
    ...(
      summary === null || typeof summary === "string"
        ? { summary: summary as ResponsesReasoningConfig["summary"] }
        : {}
    ),
  };
  return Object.keys(normalized).length > 0 ? normalized : undefined;
}

export function extractResponsesTextConfig(payload: unknown): ResponsesTextConfig | undefined {
  return isRecord(payload) && isRecord(payload.text) ? payload.text : undefined;
}

export function messageMatchesModel(message: unknown, model: ModelLike): boolean {
  if (!isRecord(message)) return false;
  return message.provider === model.provider && message.model === model.id;
}
