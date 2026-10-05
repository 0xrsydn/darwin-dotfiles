/**
 * claude-bridge — use a Claude Pro/Max subscription from pi through the real
 * Claude Code CLI.
 *
 * Why the CLI and not an HTTP provider: pi's built-in Anthropic provider speaks
 * the Messages API directly, and Anthropic treats that as a third-party harness,
 * billed as extra usage. Requests made by the `claude` binary count as Claude
 * Code usage. This extension therefore spawns the CLI and never sends an
 * Anthropic request itself.
 *
 * How the two agent loops fit together: pi keeps the outer loop (it decides when
 * to call the model and it executes tools). The CLI keeps a per-session process
 * whose inner loop picks the next tool and then yields. It yields because every
 * tool call arrives at ./mcp.ts as an HTTP `tools/call`, and that handler blocks
 * until pi delivers the result through the next `streamSimple` call.
 *
 * Deliberate limits compared with pi-claude-bridge:
 *   - one CLI process per pi session, no Claude Code session files
 *   - restarts restore Pi's active transcript as labeled conversation records
 *   - live tool results are delivered through the blocked handler only
 *   - images are forwarded; skills, hooks guidance, and `AskClaude` are not
 */
import { spawn, type ChildProcessWithoutNullStreams } from "node:child_process";
import { mkdtempSync, rmSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
import {
  calculateCost,
  createAssistantMessageEventStream,
  getCurrentSystemPrompt,
  getCurrentTools,
  type AssistantMessage,
  type AssistantMessageEventStream,
  type Model,
  type SimpleStreamOptions,
  type Tool,
  type UserMessage,
} from "@earendil-works/pi-ai";
import { getModels } from "@earendil-works/pi-ai/compat";
import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";
import {
  startToolServer,
  type McpContent,
  type McpResult,
  type McpToolSchema,
  type ToolServer,
} from "./mcp.ts";
import { extendsTranscript, restoredContent, transcriptKeys, type TranscriptMessage } from "./transcript.ts";

const PROVIDER_ID = "claude-bridge";
const MCP_SERVER_NAME = "pi";
/** How Claude Code names a pi tool in its own tool list and in `tool_use` blocks. */
const MCP_TOOL_PREFIX = `mcp__${MCP_SERVER_NAME}__`;

/**
 * Variables removed from the CLI environment. An exported `ANTHROPIC_API_KEY`
 * takes precedence over the claude.ai login, so the bridge would silently bill a
 * pay-per-token key instead of the subscription. `ANTHROPIC_BASE_URL` redirects
 * the CLI to a gateway, which fails every turn.
 */
const STRIPPED_ANTHROPIC_VARS = [
  "ANTHROPIC_API_KEY",
  "ANTHROPIC_AUTH_TOKEN",
  "ANTHROPIC_BASE_URL",
  "ANTHROPIC_FOUNDRY_API_KEY",
];

const CHILD_ENV = {
  // Keep claude.ai cloud connectors out of a pi session, which serves its own tools.
  ENABLE_CLAUDEAI_MCP_SERVERS: "0",
  // pi owns compaction. The CLI compacting its own copy would diverge from pi.
  DISABLE_AUTO_COMPACT: "1",
  // Lets user hooks written for Claude Code skip themselves under pi.
  PI_CODING_AGENT: "true",
};

/** pi thinking level -> CLI `--effort` level. */
const EFFORT_BY_THINKING_LEVEL: Record<string, string> = {
  minimal: "low",
  low: "low",
  medium: "medium",
  high: "high",
  xhigh: "xhigh",
  max: "max",
};

type ContentBlock =
  | { type: "text"; text: string; index: number }
  | { type: "thinking"; thinking: string; thinkingSignature: string; index: number }
  | {
      type: "toolCall";
      id: string;
      name: string;
      arguments: Record<string, unknown>;
      partialJson: string;
      index: number;
    };

type PendingCall = {
  name: string;
  resolve: (result: McpResult) => void;
};

type Session = {
  readonly key: string;
  /** Set for one-off summarizer calls that must not touch the session process. */
  readonly isolated: boolean;
  child: ChildProcessWithoutNullStreams | null;
  toolServer: ToolServer | null;
  /** The server serves the current tool set; CLI restarts refresh its cache. */
  toolSchemas: McpToolSchema[];
  mcpConfigDir: string | null;
  model: Model<any> | null;
  stream: AssistantMessageEventStream | null;
  output: AssistantMessage | null;
  blocks: ContentBlock[];
  started: boolean;
  pending: Map<string, PendingCall>;
  expectedCalls: Map<string, string>;
  streamedMessageIds: Set<string>;
  /** Results that arrived before Claude Code issued the matching `tools/call`. */
  queuedResults: Map<string, McpResult>;
  systemPrompt: string;
  cwd: string;
  stderrTail: string;
  aborted: AbortSignal | null;
  detachAbort: (() => void) | null;
  requestMessages: TranscriptMessage[];
  checkpoint: string[];
  childConfig: string;
  /** Invalidate setup work and callbacks from an aborted or replaced request. */
  generation: number;
};

const sessions = new Map<string, Session>();
let isolatedCounter = 0;

// ---------------------------------------------------------------------------
// pi <-> Claude Code conversion
// ---------------------------------------------------------------------------

function stripToolPrefix(name: string): string {
  return name.startsWith(MCP_TOOL_PREFIX) ? name.slice(MCP_TOOL_PREFIX.length) : name;
}

function toMcpTools(tools: Tool[]): McpToolSchema[] {
  const schemas: McpToolSchema[] = [];
  for (const tool of tools) {
    const parameters = tool.parameters as { type?: string } | undefined;
    // MCP requires an object schema. Omit tools with unsupported schemas.
    if (!parameters || parameters.type !== "object") continue;
    schemas.push({
      name: tool.name,
      description: tool.description ?? "",
      inputSchema: parameters,
    });
  }
  return schemas;
}

function toClaudeContent(
  content: UserMessage["content"] | string,
): Array<Record<string, unknown>> {
  if (typeof content === "string") {
    return content ? [{ type: "text", text: content }] : [];
  }
  const blocks: Array<Record<string, unknown>> = [];
  if (!Array.isArray(content)) return blocks;
  for (const block of content) {
    if (block.type === "text" && block.text) {
      blocks.push({ type: "text", text: block.text });
    } else if (block.type === "image" && block.data) {
      blocks.push({
        type: "image",
        source: { type: "base64", media_type: block.mimeType, data: block.data },
      });
    }
  }
  return blocks;
}

function toMcpContent(content: unknown): McpContent[] {
  if (typeof content === "string") return [{ type: "text", text: content }];
  const blocks: McpContent[] = [];
  if (Array.isArray(content)) {
    for (const block of content as Array<{ type?: string; text?: string; data?: string; mimeType?: string }>) {
      if (block.type === "text" && block.text) blocks.push({ type: "text", text: block.text });
      else if (block.type === "image" && block.data && block.mimeType) {
        blocks.push({ type: "image", data: block.data, mimeType: block.mimeType });
      }
    }
  }
  return blocks.length ? blocks : [{ type: "text", text: "" }];
}

/**
 * Collect this turn's tool results and any steer pi injected before them.
 *
 * pi appends tool results to the transcript and calls the provider again. The
 * walk stops at the nearest assistant message, which is the turn boundary, and
 * collects user messages to detect steering. Steering with results requires a
 * new CLI request with the active transcript restored.
 */
function collectTail(messages: Array<{ role: string; [key: string]: unknown }>): {
  steers: UserMessage[];
  results: Array<McpResult & { toolCallId?: string }>;
} {
  const steers: UserMessage[] = [];
  const results: Array<McpResult & { toolCallId?: string }> = [];
  for (let i = messages.length - 1; i >= 0; i--) {
    const message = messages[i];
    if (message.role === "assistant") break;
    if (message.role === "user") {
      steers.unshift(message as unknown as UserMessage);
    } else if (message.role === "toolResult") {
      results.unshift({
        content: toMcpContent(message.content),
        isError: Boolean(message.isError),
        toolCallId: typeof message.toolCallId === "string" ? message.toolCallId : undefined,
      });
    }
  }
  return { steers, results };
}

function mapStopReason(reason: string | undefined): "stop" | "length" | "toolUse" {
  if (reason === "max_tokens") return "length";
  if (reason === "tool_use") return "toolUse";
  return "stop";
}

type ClaudeUsage = {
  input_tokens?: number | null;
  output_tokens?: number | null;
  cache_read_input_tokens?: number | null;
  cache_creation_input_tokens?: number | null;
};

function applyUsage(output: AssistantMessage, usage: ClaudeUsage | undefined, model: Model<any>): void {
  if (!usage) return;
  if (usage.input_tokens != null) output.usage.input = usage.input_tokens;
  if (usage.output_tokens != null) output.usage.output = usage.output_tokens;
  if (usage.cache_read_input_tokens != null) output.usage.cacheRead = usage.cache_read_input_tokens;
  if (usage.cache_creation_input_tokens != null) {
    output.usage.cacheWrite = usage.cache_creation_input_tokens;
  }
  output.usage.totalTokens =
    output.usage.input + output.usage.output + output.usage.cacheRead + output.usage.cacheWrite;
  calculateCost(model, output.usage);
}

// ---------------------------------------------------------------------------
// Turn and stream lifecycle
// ---------------------------------------------------------------------------

function beginTurn(session: Session, model: Model<any>): AssistantMessageEventStream {
  const blocks: ContentBlock[] = [];
  session.blocks = blocks;
  session.output = {
    role: "assistant",
    content: blocks as unknown as AssistantMessage["content"],
    api: model.api,
    provider: model.provider,
    model: model.id,
    usage: {
      input: 0,
      output: 0,
      cacheRead: 0,
      cacheWrite: 0,
      totalTokens: 0,
      cost: { input: 0, output: 0, cacheRead: 0, cacheWrite: 0, total: 0 },
    },
    stopReason: "pending",
    timestamp: Date.now(),
  };
  session.started = false;
  const stream = createAssistantMessageEventStream();
  session.stream = stream;
  return stream;
}

function ensureStarted(session: Session): void {
  if (session.started || !session.stream || !session.output) return;
  session.stream.push({ type: "start", partial: session.output });
  session.started = true;
}

function finishTurn(
  session: Session,
  reason: "stop" | "length" | "toolUse" | "error" | "aborted",
  errorMessage?: string,
): void {
  const stream = session.stream;
  const output = session.output;
  if (!stream || !output) return;
  ensureStarted(session);

  if (reason === "error" || reason === "aborted") {
    output.stopReason = reason;
    output.errorMessage = errorMessage ?? output.errorMessage;
    stream.push({ type: "error", reason, error: output });
  } else {
    output.stopReason = reason;
    stream.push({ type: "done", reason, message: output });
  }
  session.checkpoint = transcriptKeys([...session.requestMessages, output as unknown as TranscriptMessage]);
  stream.end();
  session.stream = null;
  if (reason !== "toolUse") {
    session.detachAbort?.();
    session.detachAbort = null;
    session.aborted = null;
  }
}

function releasePending(session: Session, text: string): void {
  for (const pending of session.pending.values()) {
    pending.resolve({ content: [{ type: "text", text }], isError: true });
  }
  session.pending.clear();
  session.expectedCalls.clear();
  session.streamedMessageIds.clear();
  session.queuedResults.clear();
}

function findBlock(session: Session, index: number): ContentBlock | undefined {
  return session.blocks.find((block) => block.index === index);
}

function handleStreamEvent(session: Session, event: any): void {
  const output = session.output;
  const stream = session.stream;
  if (!output || !stream) return;

  switch (event?.type) {
    case "message_start":
      if (event.message?.id) session.streamedMessageIds.add(event.message.id);
      applyUsage(output, event.message?.usage, session.model!);
      return;

    case "content_block_start": {
      if (!stream) return;
      const index = event.index as number;
      const block = event.content_block;
      if (block?.type === "text") {
        session.blocks.push({ type: "text", text: "", index });
        ensureStarted(session);
        stream.push({ type: "text_start", contentIndex: session.blocks.length - 1, partial: output });
      } else if (block?.type === "thinking") {
        session.blocks.push({ type: "thinking", thinking: "", thinkingSignature: "", index });
        ensureStarted(session);
        stream.push({ type: "thinking_start", contentIndex: session.blocks.length - 1, partial: output });
      } else if (block?.type === "tool_use") {
        session.expectedCalls.set(block.id, stripToolPrefix(String(block.name)));
        session.blocks.push({
          type: "toolCall",
          id: block.id,
          name: stripToolPrefix(String(block.name)),
          arguments: (block.input as Record<string, unknown>) ?? {},
          partialJson: "",
          index,
        });
        ensureStarted(session);
        stream.push({ type: "toolcall_start", contentIndex: session.blocks.length - 1, partial: output });
      }
      return;
    }

    case "content_block_delta": {
      if (!stream) return;
      const block = findBlock(session, event.index as number);
      const contentIndex = block ? session.blocks.indexOf(block) : -1;
      if (!block || contentIndex < 0) return;
      const delta = event.delta;
      if (delta?.type === "text_delta" && block.type === "text") {
        block.text += delta.text;
        stream.push({ type: "text_delta", contentIndex, delta: delta.text, partial: output });
      } else if (delta?.type === "thinking_delta" && block.type === "thinking") {
        block.thinking += delta.thinking;
        stream.push({ type: "thinking_delta", contentIndex, delta: delta.thinking, partial: output });
      } else if (delta?.type === "input_json_delta" && block.type === "toolCall") {
        block.partialJson += delta.partial_json ?? "";
        block.arguments = parsePartialJson(block.partialJson);
        stream.push({ type: "toolcall_delta", contentIndex, delta: delta.partial_json ?? "", partial: output });
      } else if (delta?.type === "signature_delta" && block.type === "thinking") {
        block.thinkingSignature += delta.signature ?? "";
      }
      return;
    }

    case "content_block_stop": {
      if (!stream) return;
      const block = findBlock(session, event.index as number);
      if (!block) return;
      const contentIndex = session.blocks.indexOf(block);
      if (block.type === "text") {
        stream.push({ type: "text_end", contentIndex, content: block.text, partial: output });
      } else if (block.type === "thinking") {
        stream.push({ type: "thinking_end", contentIndex, content: block.thinking, partial: output });
      } else if (block.type === "toolCall") {
        if (block.partialJson) block.arguments = parsePartialJson(block.partialJson);
        const toolCall = {
          type: "toolCall" as const,
          id: block.id,
          name: block.name,
          arguments: block.arguments,
        };
        stream.push({ type: "toolcall_end", contentIndex, toolCall: toolCall as never, partial: output });
      }
      return;
    }

    case "message_delta":
      if (event.delta?.stop_reason) output.stopReason = mapStopReason(event.delta.stop_reason);
      applyUsage(output, event.usage, session.model!);
      return;

    case "message_stop": {
      if (!session.stream) return;
      const sawToolCall = session.blocks.some((block) => block.type === "toolCall");
      if (sawToolCall) {
        // End the pi turn so pi executes the tool. The handler in ./mcp.ts stays
        // blocked until pi calls streamSimple again with the results.
        finishTurn(session, "toolUse");
      }
      // A text message_stop is not the CLI turn boundary. Wait for result so
      // a late result cannot close the next Pi request's stream.
      return;
    }

    default:
      return;
  }
}

function parsePartialJson(text: string): Record<string, unknown> {
  const trimmed = text.trim();
  if (!trimmed) return {};
  try {
    const parsed = JSON.parse(trimmed);
    return typeof parsed === "object" && parsed !== null ? (parsed as Record<string, unknown>) : {};
  } catch {
    return {};
  }
}

/**
 * Content path used when Claude Code answers without streaming events, which
 * happens when its stream stalls and it retries non-streaming. Stream events
 * already filled the blocks in the common case, so this only acts on an empty
 * turn.
 */
function handleAssistantMessage(session: Session, message: any): void {
  if (!session.stream || !session.output) return;
  if (message?.id && session.streamedMessageIds.has(message.id)) return;
  applyUsage(session.output, message?.usage, session.model!);
  if (session.blocks.length > 0) return;

  for (const block of message?.content ?? []) {
    const index = session.blocks.length;
    if (block.type === "text") {
      session.blocks.push({ type: "text", text: block.text ?? "", index });
      ensureStarted(session);
      const contentIndex = session.blocks.length - 1;
      session.stream.push({ type: "text_start", contentIndex, partial: session.output });
      if (block.text) {
        session.stream.push({ type: "text_delta", contentIndex, delta: block.text, partial: session.output });
      }
      session.stream.push({ type: "text_end", contentIndex, content: block.text ?? "", partial: session.output });
    } else if (block.type === "thinking") {
      session.blocks.push({ type: "thinking", thinking: block.thinking ?? "", thinkingSignature: "", index });
      ensureStarted(session);
      const contentIndex = session.blocks.length - 1;
      session.stream.push({ type: "thinking_start", contentIndex, partial: session.output });
      session.stream.push({ type: "thinking_end", contentIndex, content: block.thinking ?? "", partial: session.output });
    } else if (block.type === "tool_use") {
      session.expectedCalls.set(block.id, stripToolPrefix(String(block.name)));
      session.blocks.push({
        type: "toolCall",
        id: block.id,
        name: stripToolPrefix(String(block.name)),
        arguments: (block.input as Record<string, unknown>) ?? {},
        partialJson: "",
        index,
      });
      ensureStarted(session);
      session.stream.push({
        type: "toolcall_start",
        contentIndex: session.blocks.length - 1,
        partial: session.output,
      });
      session.stream.push({
        type: "toolcall_end",
        contentIndex: session.blocks.length - 1,
        toolCall: {
          type: "toolCall",
          id: block.id,
          name: stripToolPrefix(String(block.name)),
          arguments: (block.input as Record<string, unknown>) ?? {},
        } as never,
        partial: session.output,
      });
    }
  }
  // A non-streaming tool response must yield before the CLI's MCP call waits
  // for Pi. Waiting for result here would deadlock both agent loops.
  if (session.blocks.some((block) => block.type === "toolCall")) finishTurn(session, "toolUse");
}

function handleResult(session: Session, message: any): void {
  // CLI result usage aggregates several model calls. Prefer per-message usage
  // so Pi does not count tool-producing responses twice.
  if (session.output && session.output.usage.totalTokens === 0) {
    applyUsage(session.output, message?.usage, session.model!);
  }
  if (message?.is_error && session.stream) {
    const errors = Array.isArray(message.errors) ? message.errors.join("\n") : undefined;
    finishTurn(session, "error", String(errors ?? message.result ?? message.subtype ?? "Claude Code failed"));
  } else if (session.stream) {
    finishTurn(session, message?.stop_reason === "max_tokens" || session.output?.stopReason === "length" ? "length" : "stop");
  }
  releasePending(session, "Claude Code request finished");
  if (session.isolated) {
    void (async () => {
      await stopChild(session);
      sessions.delete(session.key);
      if (session.mcpConfigDir) rmSync(session.mcpConfigDir, { recursive: true, force: true });
    })();
  }
}

function handleClaudeMessage(session: Session, message: any): void {
  switch (message?.type) {
    case "system":
      return;
    case "stream_event":
      handleStreamEvent(session, message.event);
      return;
    case "assistant":
      handleAssistantMessage(session, message.message);
      return;
    case "result":
      handleResult(session, message);
      return;
    default:
      return;
  }
}

// ---------------------------------------------------------------------------
// CLI process lifecycle
// ---------------------------------------------------------------------------

function childEnvironment(): NodeJS.ProcessEnv {
  const env: NodeJS.ProcessEnv = { ...process.env, ...CHILD_ENV };
  for (const name of STRIPPED_ANTHROPIC_VARS) delete env[name];
  return env;
}

function drainStdout(session: Session, chunk: string, buffer: { value: string }): void {
  buffer.value += chunk;
  let newline = buffer.value.indexOf("\n");
  while (newline !== -1) {
    const line = buffer.value.slice(0, newline).trim();
    buffer.value = buffer.value.slice(newline + 1);
    if (line) {
      let message: unknown;
      try {
        message = JSON.parse(line);
      } catch {
        // Ignore non-protocol output without hiding event-handler failures.
        newline = buffer.value.indexOf("\n");
        continue;
      }
      try {
        handleClaudeMessage(session, message);
      } catch (error) {
        finishTurn(session, "error", error instanceof Error ? error.message : String(error));
        void stopChild(session);
        return;
      }
    }
    newline = buffer.value.indexOf("\n");
  }
}

function startChild(session: Session, model: Model<any>, options: SimpleStreamOptions | undefined): void {
  const args = [
    "--print",
    "--input-format",
    "stream-json",
    "--output-format",
    "stream-json",
    "--verbose",
    "--include-partial-messages",
    "--no-session-persistence",
    // Disable Claude Code's built-in tools: every tool the model may call is a pi tool.
    "--tools",
    "",
    // pi handles approval, so the CLI must not stop for permissions.
    "--permission-mode",
    "bypassPermissions",
    // The CLI replaces its own prompt with pi's. Inline because this CLI
    // version has no --system-prompt-file; pi's prompt is far below ARG_MAX.
    "--system-prompt",
    session.systemPrompt,
    "--model",
    model.id,
    "--add-dir",
    session.cwd,
  ];

  if (session.toolServer) {
    args.push("--strict-mcp-config", "--mcp-config", mcpConfigPath(session));
  } else {
    args.push("--strict-mcp-config");
  }

  const effort = effortLevel(options);
  if (effort) args.push("--effort", effort);

  const child = spawn("claude", args, {
    cwd: session.cwd,
    env: childEnvironment(),
    stdio: ["pipe", "pipe", "pipe"],
  }) as ChildProcessWithoutNullStreams;

  session.child = child;
  session.stderrTail = "";

  const buffer = { value: "" };
  child.stdout.setEncoding("utf8");
  child.stdout.on("data", (chunk: string) => {
    if (session.child === child) drainStdout(session, chunk, buffer);
  });
  child.stdin.on("error", (error) => {
    if (session.child !== child) return;
    finishTurn(session, "error", `Claude Code stdin failed: ${error.message}`);
    void stopChild(session);
  });
  child.stderr.setEncoding("utf8");
  child.stderr.on("data", (chunk: string) => {
    if (session.child === child) session.stderrTail = (session.stderrTail + chunk).slice(-2000);
  });
  child.on("exit", (code) => {
    if (session.child !== child) return;
    session.child = null;
    if (session.stream) {
      finishTurn(
        session,
        session.aborted?.aborted ? "aborted" : "error",
        session.aborted?.aborted
          ? "Operation aborted"
          : `Claude Code exited with code ${code}. ${session.stderrTail}`.trim(),
      );
    }
    releasePending(session, "Claude Code exited");
  });
  child.on("error", (error) => {
    if (session.child !== child) return;
    session.child = null;
    if (session.stream) finishTurn(session, "error", `Failed to start Claude Code: ${error.message}`);
    releasePending(session, "Failed to start Claude Code");
  });
}

function mcpConfigPath(session: Session): string {
  return join(session.mcpConfigDir!, "mcp.json");
}

function writeMcpConfig(session: Session, url: string): void {
  writeFileSync(
    mcpConfigPath(session),
    JSON.stringify({ mcpServers: { [MCP_SERVER_NAME]: { type: "http", url } } }),
    "utf8",
  );
}

function effortLevel(options: SimpleStreamOptions | undefined): string | undefined {
  return EFFORT_BY_THINKING_LEVEL[options?.reasoning ?? (options as any)?.thinkingLevel ?? ""];
}

function childConfig(model: Model<any>, systemPrompt: string, tools: McpToolSchema[], options?: SimpleStreamOptions): string {
  return JSON.stringify({ model: model.id, systemPrompt, tools, effort: effortLevel(options) });
}

async function ensureChild(
  session: Session,
  model: Model<any>,
  systemPrompt: string,
  options: SimpleStreamOptions | undefined,
  generation: number,
): Promise<void> {
  if (generation !== session.generation || options?.signal?.aborted) return;
  if (!session.mcpConfigDir) session.mcpConfigDir = mkdtempSync(join(tmpdir(), "pi-claude-bridge-"));
  session.systemPrompt = systemPrompt;

  // One tool server per session. It survives a child restart because it holds
  // the pending-call map the new child will use.
  if (!session.toolServer && !session.isolated) {
    const server = await startToolServer({
      listTools: () => session.toolSchemas,
      callTool: (name, toolUseId) => callTool(session, name, toolUseId),
    });
    if (generation !== session.generation || options?.signal?.aborted) {
      await server.close();
      return;
    }
    session.toolServer = server;
    writeMcpConfig(session, server.url);
  }

  if (generation !== session.generation || options?.signal?.aborted) return;
  if (!session.child) {
    session.childConfig = childConfig(model, systemPrompt, session.toolSchemas, options);
    startChild(session, model, options);
  }
}

async function stopChild(session: Session): Promise<void> {
  const child = session.child;
  session.child = null;
  releasePending(session, "Claude Code stopped");
  if (child) {
    // All child callbacks check identity. Ignore any buffered old-process
    // events after replacing it, but keep the error listener installed.
    child.kill("SIGTERM");
    const exited = new Promise<void>((resolve) => child.once("close", () => resolve()));
    const timer = setTimeout(() => child.kill("SIGKILL"), 1000);
    timer.unref();
    await exited;
    clearTimeout(timer);
  }
}

function writeUserMessage(session: Session, user: UserMessage): void {
  if (!session.child?.stdin.writable) throw new Error("Claude Code stdin is not writable");
  const content = toClaudeContent(user.content);
  if (!content.length) content.push({ type: "text", text: "Continue the conversation." });
  session.child.stdin.write(
    `${JSON.stringify({ type: "user", message: { role: "user", content } })}\n`,
  );
}

function deliverResult(session: Session, result: McpResult & { toolCallId?: string }): void {
  const id = result.toolCallId;
  if (!id) return;
  const pending = session.pending.get(id);
  if (pending) {
    session.pending.delete(id);
    pending.resolve({ content: result.content, isError: result.isError });
    return;
  }
  // The tool finished before Claude Code asked for it.
  session.queuedResults.set(id, { content: result.content, isError: result.isError });
}

async function callTool(session: Session, name: string, toolUseId: string): Promise<McpResult> {
  if (session.expectedCalls.get(toolUseId) !== name) {
    throw new Error(`Unknown tool call: ${name} (${toolUseId})`);
  }
  if (session.pending.has(toolUseId)) throw new Error(`Duplicate tool call: ${toolUseId}`);
  const queued = session.queuedResults.get(toolUseId);
  if (queued) {
    session.queuedResults.delete(toolUseId);
    return queued;
  }
  return new Promise<McpResult>((resolve) => {
    session.pending.set(toolUseId, { name, resolve });
  });
}

// ---------------------------------------------------------------------------
// Session lookup and provider entry point
// ---------------------------------------------------------------------------

function getSession(key: string, isolated: boolean): Session {
  let session = sessions.get(key);
  if (!session) {
    session = {
      key,
      isolated,
      child: null,
      toolServer: null,
      mcpConfigDir: null,
      model: null,
      toolSchemas: [],
      stream: null,
      output: null,
      blocks: [],
      started: false,
      pending: new Map(),
      expectedCalls: new Map(),
      streamedMessageIds: new Set(),
      queuedResults: new Map(),
      systemPrompt: "",
      cwd: process.cwd(),
      stderrTail: "",
      aborted: null,
      detachAbort: null,
      requestMessages: [],
      checkpoint: [],
      childConfig: "",
      generation: 0,
    };
    sessions.set(key, session);
  }
  return session;
}

function attachAbort(session: Session, signal: AbortSignal | undefined): void {
  session.detachAbort?.();
  session.detachAbort = null;
  session.aborted = signal ?? null;
  if (!signal) return;
  const abort = () => {
    session.generation++;
    releasePending(session, "Operation aborted");
    if (session.stream) finishTurn(session, "aborted", "Operation aborted");
    void stopChild(session);
  };
  session.detachAbort = () => signal.removeEventListener("abort", abort);
  signal.addEventListener("abort", abort, { once: true });
  if (signal.aborted) abort();
}

function streamSimple(
  model: Model<any>,
  context: { messages: TranscriptMessage[] },
  options?: SimpleStreamOptions,
): AssistantMessageEventStream {
  const isolated = options?.cacheRetention === "none";
  const key = isolated ? `isolated:${++isolatedCounter}` : (options?.sessionId ?? "default");
  const session = getSession(String(key), isolated);
  const messages = context.messages;
  const tools = getCurrentTools(messages as never) as Tool[];
  const systemPrompt = getCurrentSystemPrompt(messages as never) ?? "";
  const keys = transcriptKeys(messages);
  const appended = messages.filter((message) => message.role !== "system").slice(session.checkpoint.length);
  const schemas = isolated ? [] : toMcpTools(tools);
  const canReuse = Boolean(session.child) && extendsTranscript(session.checkpoint, keys) &&
    session.childConfig === childConfig(model, systemPrompt, schemas, options);
  const { steers, results } = collectTail(messages);
  // A steer plus tool results starts a fresh CLI request with restored context.
  // Sending a separate stdin user message while MCP is blocked would create two
  // CLI results for one Pi request and reintroduce the turn-boundary race.
  const canDeliver = canReuse && results.length > 0 && steers.length === 0 &&
    results.every((result) => result.toolCallId && session.expectedCalls.has(result.toolCallId));
  const canSend = canReuse && results.length === 0 && appended.length > 0 &&
    appended.every((message) => message.role === "user");
  const restart = !canDeliver && !canSend;

  session.model = model;
  session.toolSchemas = schemas;
  session.requestMessages = messages.slice();
  const generation = ++session.generation;
  const stream = beginTurn(session, model);
  attachAbort(session, options?.signal);
  if (options?.signal?.aborted) return stream;

  void (async () => {
    try {
      if (restart) await stopChild(session);
      if (generation !== session.generation || options?.signal?.aborted) return;
      await ensureChild(session, model, systemPrompt, options, generation);
      if (generation !== session.generation || options?.signal?.aborted) return;
      if (canDeliver) {
        for (const result of results) deliverResult(session, result);
      } else {
        // Combine appended user messages into one CLI request. This also keeps
        // injected shell output or custom context before the latest user input.
        const content = restart ? restoredContent(messages) : appended.flatMap((message) => {
          const user = message as unknown as UserMessage;
          return typeof user.content === "string" ? [{ type: "text" as const, text: user.content }] : user.content;
        });
        writeUserMessage(session, { role: "user", content, timestamp: Date.now() });
      }
    } catch (error) {
      if (generation !== session.generation) return;
      finishTurn(session, "error", error instanceof Error ? error.message : String(error));
      await stopChild(session);
    }
  })();
  return stream;
}

// ---------------------------------------------------------------------------
// Models from pi-ai's Anthropic catalog
// ---------------------------------------------------------------------------

function buildModels(): Array<Record<string, unknown>> {
  return (getModels("anthropic") as Array<Record<string, any>>)
    // Dated snapshot ids (claude-opus-4-5-20251101) never show in the picker.
    .filter((entry) => typeof entry.id === "string" && !/-20\d{6}$/.test(entry.id))
    .map((entry) => ({
      id: entry.id,
      name: entry.name ?? entry.id,
      reasoning: Boolean(entry.reasoning),
      input: entry.input ?? ["text", "image"],
      contextWindow: entry.contextWindow ?? 200_000,
      maxTokens: entry.maxTokens ?? 64_000,
      // The subscription has no per-token price, so pi reports zero cost and
      // only token counts.
      cost: { input: 0, output: 0, cacheRead: 0, cacheWrite: 0 },
    }));
}

export default function (pi: ExtensionAPI) {
  const models = buildModels();
  if (models.length === 0) {
    console.error(
      "claude-bridge: no models from pi-ai's anthropic catalog. Update @earendil-works/pi-ai.",
    );
    return;
  }

  pi.registerProvider(PROVIDER_ID, {
    baseUrl: PROVIDER_ID,
    apiKey: "claude-code-cli",
    api: "claude-bridge",
    models,
    streamSimple,
  } as never);

  pi.on("session_shutdown", async () => {
    for (const session of sessions.values()) {
      session.generation++;
      session.detachAbort?.();
      await stopChild(session);
      await session.toolServer?.close();
      if (session.mcpConfigDir) rmSync(session.mcpConfigDir, { recursive: true, force: true });
    }
    sessions.clear();
  });
}
