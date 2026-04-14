import * as fs from "node:fs";
import * as os from "node:os";
import * as path from "node:path";
import {
  type ExtensionAPI,
  DEFAULT_MAX_BYTES,
  DEFAULT_MAX_LINES,
  formatSize,
  truncateHead,
} from "@mariozechner/pi-coding-agent";
import { StringEnum } from "@mariozechner/pi-ai";
import { Type } from "@sinclair/typebox";

const EXA_API_BASE = "https://api.exa.ai";
const DEFAULT_SEARCH_RESULTS = 5;
const MAX_SEARCH_RESULTS = 10;
const DEFAULT_HIGHLIGHT_CHARS = 1200;
const DEFAULT_CODE_TOKENS = 5000;
const MAX_CODE_TOKENS = 12000;

function clip(text: string, max = 400): string {
  const normalized = text.replace(/\s+/g, " ").trim();
  return normalized.length > max ? `${normalized.slice(0, max)}…` : normalized;
}

function maybeString(value: unknown): string | undefined {
  return typeof value === "string" && value.trim() ? value.trim() : undefined;
}

function stringArray(value: unknown): string[] {
  if (!Array.isArray(value)) return [];
  return value.filter((item): item is string => typeof item === "string" && item.trim().length > 0);
}

function readSecretFile(secretPath: string): string | undefined {
  try {
    if (!fs.existsSync(secretPath)) return undefined;
    const value = fs.readFileSync(secretPath, "utf8").trim();
    return value || undefined;
  } catch {
    return undefined;
  }
}

function resolveExaApiKey(): { key?: string; source: string } {
  const envKey = process.env.EXA_API_KEY?.trim();
  if (envKey) return { key: envKey, source: "EXA_API_KEY" };

  const secretCandidates = [
    path.join(os.homedir(), ".config", "secrets", "exa-api-key"),
    path.join(os.homedir(), ".config", "secrets", "exa_api_key"),
  ];

  for (const secretPath of secretCandidates) {
    const value = readSecretFile(secretPath);
    if (value) return { key: value, source: secretPath };
  }

  return { source: "missing" };
}

async function postExa(pathname: string, payload: Record<string, unknown>, signal?: AbortSignal): Promise<any> {
  const auth = resolveExaApiKey();
  if (!auth.key) {
    throw new Error(
      "Exa API key not found. Set EXA_API_KEY or create ~/.config/secrets/exa-api-key.",
    );
  }

  const response = await fetch(`${EXA_API_BASE}${pathname}`, {
    method: "POST",
    headers: {
      "content-type": "application/json",
      "x-api-key": auth.key,
    },
    body: JSON.stringify(payload),
    signal,
  });

  const raw = await response.text();
  let data: any;
  try {
    data = raw ? JSON.parse(raw) : {};
  } catch {
    data = { raw };
  }

  if (!response.ok) {
    const detail = typeof data === "object" && data && maybeString(data.error) ? data.error : clip(raw, 600);
    throw new Error(`Exa request failed (${response.status} ${response.statusText}): ${detail}`);
  }

  if (typeof data === "object" && data && maybeString(data.error)) {
    const tag = maybeString(data.tag);
    throw new Error(`Exa error${tag ? ` [${tag}]` : ""}: ${data.error}`);
  }

  return data;
}

async function writeTempOutput(prefix: string, content: string): Promise<string> {
  const dir = await fs.promises.mkdtemp(path.join(os.tmpdir(), "pi-exa-tools-"));
  const filePath = path.join(dir, `${prefix}.txt`);
  await fs.promises.writeFile(filePath, content, "utf8");
  return filePath;
}

async function finalizeText(prefix: string, fullText: string): Promise<{ text: string; fullOutputPath?: string }> {
  const truncation = truncateHead(fullText, {
    maxLines: DEFAULT_MAX_LINES,
    maxBytes: DEFAULT_MAX_BYTES,
  });

  if (!truncation.truncated) {
    return { text: truncation.content };
  }

  const fullOutputPath = await writeTempOutput(prefix, fullText);
  const notice = [
    "",
    `[Output truncated: ${truncation.outputLines} of ${truncation.totalLines} lines (${formatSize(truncation.outputBytes)} of ${formatSize(truncation.totalBytes)}). Full output saved to: ${fullOutputPath}]`,
  ].join("\n");

  return {
    text: `${truncation.content}${notice}`,
    fullOutputPath,
  };
}

function formatSearchResult(result: any, index: number, includeText: boolean): string {
  const title = maybeString(result?.title) ?? maybeString(result?.url) ?? `Result ${index + 1}`;
  const lines = [`${index + 1}. ${title}`];

  const url = maybeString(result?.url);
  if (url) lines.push(`   URL: ${url}`);

  const published = maybeString(result?.publishedDate) ?? maybeString(result?.published_date);
  if (published) lines.push(`   Published: ${published}`);

  const author = maybeString(result?.author);
  if (author) lines.push(`   Author: ${author}`);

  const summary = maybeString(result?.summary);
  if (summary) lines.push(`   Summary: ${clip(summary, 500)}`);

  const highlights = stringArray(result?.highlights);
  if (highlights.length > 0) {
    lines.push("   Highlights:");
    for (const highlight of highlights.slice(0, 3)) {
      lines.push(`   - ${clip(highlight, 350)}`);
    }
  }

  if (includeText) {
    const text = maybeString(result?.text);
    if (text) lines.push(`   Text: ${clip(text, 700)}`);
  }

  return lines.join("\n");
}

async function buildSearchOutput(query: string, payload: Record<string, unknown>, data: any): Promise<{ text: string; fullOutputPath?: string }> {
  const results = Array.isArray(data?.results) ? data.results : [];
  const includeText = Boolean((payload.contents as any)?.text);
  const lines: string[] = [
    `Exa search results for: ${query}`,
    `Results returned: ${results.length}`,
  ];

  const requestId = maybeString(data?.requestId);
  if (requestId) lines.push(`Request ID: ${requestId}`);

  const costTotal = data?.costDollars?.total;
  if (typeof costTotal === "number") lines.push(`Cost: $${costTotal}`);

  lines.push("");

  if (results.length === 0) {
    lines.push("No results returned.");
  } else {
    for (const [index, result] of results.entries()) {
      lines.push(formatSearchResult(result, index, includeText));
      if (index < results.length - 1) lines.push("");
    }
  }

  return finalizeText("exa-search", lines.join("\n"));
}

async function buildCodeOutput(query: string, data: any): Promise<{ text: string; fullOutputPath?: string }> {
  const context =
    maybeString(data?.context) ??
    maybeString(data?.text) ??
    maybeString(data?.output) ??
    maybeString(data?.result);

  const lines: string[] = [`Exa code context for: ${query}`];

  const requestId = maybeString(data?.requestId);
  if (requestId) lines.push(`Request ID: ${requestId}`);

  if (typeof data?.resultsCount === "number") lines.push(`Results count: ${data.resultsCount}`);
  if (typeof data?.outputTokens === "number") lines.push(`Output tokens: ${data.outputTokens}`);
  if (typeof data?.searchTime === "number") lines.push(`Search time: ${Math.round(data.searchTime)}ms`);
  if (typeof data?.costDollars?.total === "number") lines.push(`Cost: $${data.costDollars.total}`);

  lines.push("");

  if (context) {
    lines.push(context.trim());
  } else if (Array.isArray(data?.results)) {
    lines.push("No combined context field returned. Raw result excerpts:");
    lines.push("");
    for (const [index, result] of data.results.entries()) {
      const title = maybeString(result?.title) ?? maybeString(result?.url) ?? `Result ${index + 1}`;
      lines.push(`${index + 1}. ${title}`);
      const url = maybeString(result?.url);
      if (url) lines.push(`   URL: ${url}`);
      const text = maybeString(result?.text) ?? maybeString(result?.snippet);
      if (text) lines.push(`   ${clip(text, 900)}`);
      lines.push("");
    }
  } else {
    lines.push("No code context returned.");
  }

  return finalizeText("exa-code", lines.join("\n"));
}

const SearchType = StringEnum(["auto", "neural", "keyword", "deep", "deep-lite", "deep-reasoning"] as const);

const ExaSearchParams = Type.Object({
  query: Type.String({ description: "What to search for on the web" }),
  type: Type.Optional(SearchType),
  numResults: Type.Optional(Type.Integer({ description: `Number of results to return (max ${MAX_SEARCH_RESULTS})`, default: DEFAULT_SEARCH_RESULTS })),
  category: Type.Optional(Type.String({ description: "Optional Exa category, e.g. research paper, company, news" })),
  includeDomains: Type.Optional(Type.Array(Type.String(), { description: "Restrict results to these domains" })),
  excludeDomains: Type.Optional(Type.Array(Type.String(), { description: "Exclude these domains" })),
  includeText: Type.Optional(Type.Boolean({ description: "Include raw page text excerpts", default: false })),
  includeSummary: Type.Optional(Type.Boolean({ description: "Ask Exa for result summaries", default: true })),
  summaryQuery: Type.Optional(Type.String({ description: "Optional summary focus prompt" })),
  includeHighlights: Type.Optional(Type.Boolean({ description: "Ask Exa for result highlights", default: true })),
  highlightMaxCharacters: Type.Optional(Type.Integer({ description: "Maximum characters of highlights to request", default: DEFAULT_HIGHLIGHT_CHARS })),
});

const ExaCodeParams = Type.Object({
  query: Type.String({ description: "Coding question, library usage pattern, or implementation topic to retrieve code context for" }),
  tokensNum: Type.Optional(Type.Integer({ description: `Approximate token budget for returned context (max ${MAX_CODE_TOKENS})`, default: DEFAULT_CODE_TOKENS })),
});

export default function (pi: ExtensionAPI) {
  pi.registerCommand("exa-tools", {
    description: "Show Exa tools status and credential source",
    handler: async (_args, ctx) => {
      const auth = resolveExaApiKey();
      const lines = [
        "Exa tools status",
        `API key: ${auth.key ? "configured" : "missing"}`,
        `Source: ${auth.source}`,
        "",
        "Available tools:",
        "- exa_search  -> general web/docs/reference retrieval",
        "- exa_code    -> coding examples and library usage context",
      ];

      if (ctx.hasUI) {
        ctx.ui.setEditorText(lines.join("\n"));
        ctx.ui.notify(`Exa tools ${auth.key ? "ready" : "missing API key"}`, auth.key ? "info" : "warning");
      } else {
        console.log(lines.join("\n"));
      }
    },
  });

  pi.registerTool({
    name: "exa_search",
    label: "Exa Search",
    description: "Search the web with Exa for official docs, articles, release notes, issues, and general references. Requires EXA_API_KEY.",
    promptSnippet: "Search the web for docs, references, release notes, articles, and current external information.",
    promptGuidelines: [
      "Use this for external web knowledge, not for files already in the current repository.",
      "Prefer this tool when the user asks for official docs, comparisons, release notes, or broader web research.",
    ],
    parameters: ExaSearchParams,
    async execute(_toolCallId, params, signal) {
      const numResults = Math.max(1, Math.min(params.numResults ?? DEFAULT_SEARCH_RESULTS, MAX_SEARCH_RESULTS));
      const payload: Record<string, unknown> = {
        query: params.query,
        type: params.type ?? "auto",
        numResults,
      };

      if (params.category) payload.category = params.category;
      if (params.includeDomains && params.includeDomains.length > 0) payload.includeDomains = params.includeDomains;
      if (params.excludeDomains && params.excludeDomains.length > 0) payload.excludeDomains = params.excludeDomains;

      const contents: Record<string, unknown> = {};
      if (params.includeText ?? false) contents.text = true;
      if (params.includeSummary ?? true) contents.summary = { query: params.summaryQuery ?? params.query };
      if (params.includeHighlights ?? true) {
        contents.highlights = { maxCharacters: params.highlightMaxCharacters ?? DEFAULT_HIGHLIGHT_CHARS };
      }
      if (Object.keys(contents).length > 0) payload.contents = contents;

      const data = await postExa("/search", payload, signal);
      const rendered = await buildSearchOutput(params.query, payload, data);

      return {
        content: [{ type: "text", text: rendered.text }],
        details: {
          endpoint: "/search",
          query: params.query,
          requestId: data?.requestId,
          resultsCount: Array.isArray(data?.results) ? data.results.length : undefined,
          fullOutputPath: rendered.fullOutputPath,
        },
      };
    },
  });

  pi.registerTool({
    name: "exa_code",
    label: "Exa Code",
    description: "Retrieve coding-specific context and open-source implementation examples with Exa Code. Requires EXA_API_KEY.",
    promptSnippet: "Find coding examples, library usage patterns, and implementation context from public code sources.",
    promptGuidelines: [
      "Use this when the user wants examples of how libraries, frameworks, or APIs are used in code.",
      "Prefer this over general web search when the task asks for implementation patterns or open-source examples.",
    ],
    parameters: ExaCodeParams,
    async execute(_toolCallId, params, signal) {
      const tokensNum = Math.max(500, Math.min(params.tokensNum ?? DEFAULT_CODE_TOKENS, MAX_CODE_TOKENS));
      const payload = {
        query: params.query,
        tokensNum,
      };

      const data = await postExa("/context", payload, signal);
      const rendered = await buildCodeOutput(params.query, data);

      return {
        content: [{ type: "text", text: rendered.text }],
        details: {
          endpoint: "/context",
          query: params.query,
          requestId: data?.requestId,
          resultsCount: data?.resultsCount,
          outputTokens: data?.outputTokens,
          fullOutputPath: rendered.fullOutputPath,
        },
      };
    },
  });
}
