import { spawn } from "node:child_process";
import * as fs from "node:fs";
import * as os from "node:os";
import * as path from "node:path";
import { fileURLToPath } from "node:url";
import type { AgentToolResult } from "@mariozechner/pi-agent-core";
import type { Message } from "@mariozechner/pi-ai";
import { StringEnum } from "@mariozechner/pi-ai";
import { type ExtensionAPI, getMarkdownTheme, withFileMutationQueue } from "@mariozechner/pi-coding-agent";
import { Container, Markdown, Spacer, Text } from "@mariozechner/pi-tui";
import { Type } from "@sinclair/typebox";
import { type AgentConfig, type AgentScope, type AgentSource, discoverAgents, formatAgentList } from "./agents.js";

const MAX_PARALLEL_TASKS = 8;
const MAX_CONCURRENCY = 4;
const COLLAPSED_ITEM_COUNT = 10;
const BUNDLED_PROMPTS_DIR = fileURLToPath(new URL("./prompts", import.meta.url));

function formatTokens(count: number): string {
  if (count < 1000) return count.toString();
  if (count < 10000) return `${(count / 1000).toFixed(1)}k`;
  if (count < 1000000) return `${Math.round(count / 1000)}k`;
  return `${(count / 1000000).toFixed(1)}M`;
}

function formatUsageStats(
  usage: {
    input: number;
    output: number;
    cacheRead: number;
    cacheWrite: number;
    cost: number;
    contextTokens?: number;
    turns?: number;
  },
  model?: string,
): string {
  const parts: string[] = [];
  if (usage.turns) parts.push(`${usage.turns} turn${usage.turns > 1 ? "s" : ""}`);
  if (usage.input) parts.push(`↑${formatTokens(usage.input)}`);
  if (usage.output) parts.push(`↓${formatTokens(usage.output)}`);
  if (usage.cacheRead) parts.push(`R${formatTokens(usage.cacheRead)}`);
  if (usage.cacheWrite) parts.push(`W${formatTokens(usage.cacheWrite)}`);
  if (usage.cost) parts.push(`$${usage.cost.toFixed(4)}`);
  if (usage.contextTokens && usage.contextTokens > 0) parts.push(`ctx:${formatTokens(usage.contextTokens)}`);
  if (model) parts.push(model);
  return parts.join(" ");
}

function formatToolCall(
  toolName: string,
  args: Record<string, unknown>,
  themeFg: (color: any, text: string) => string,
): string {
  const shortenPath = (pathname: string) => {
    const home = os.homedir();
    return pathname.startsWith(home) ? `~${pathname.slice(home.length)}` : pathname;
  };

  switch (toolName) {
    case "bash": {
      const command = (args.command as string) || "...";
      const preview = command.length > 60 ? `${command.slice(0, 60)}...` : command;
      return themeFg("muted", "$ ") + themeFg("toolOutput", preview);
    }
    case "read": {
      const rawPath = (args.file_path || args.path || "...") as string;
      const filePath = shortenPath(rawPath);
      const offset = args.offset as number | undefined;
      const limit = args.limit as number | undefined;
      let text = themeFg("accent", filePath);
      if (offset !== undefined || limit !== undefined) {
        const startLine = offset ?? 1;
        const endLine = limit !== undefined ? startLine + limit - 1 : "";
        text += themeFg("warning", `:${startLine}${endLine ? `-${endLine}` : ""}`);
      }
      return themeFg("muted", "read ") + text;
    }
    case "write": {
      const rawPath = (args.file_path || args.path || "...") as string;
      const filePath = shortenPath(rawPath);
      const content = (args.content || "") as string;
      const lines = content.split("\n").length;
      let text = themeFg("muted", "write ") + themeFg("accent", filePath);
      if (lines > 1) text += themeFg("dim", ` (${lines} lines)`);
      return text;
    }
    case "edit": {
      const rawPath = (args.file_path || args.path || "...") as string;
      return themeFg("muted", "edit ") + themeFg("accent", shortenPath(rawPath));
    }
    case "ls": {
      const rawPath = (args.path || ".") as string;
      return themeFg("muted", "ls ") + themeFg("accent", shortenPath(rawPath));
    }
    case "find": {
      const pattern = (args.pattern || "*") as string;
      const rawPath = (args.path || ".") as string;
      return themeFg("muted", "find ") + themeFg("accent", pattern) + themeFg("dim", ` in ${shortenPath(rawPath)}`);
    }
    case "grep": {
      const pattern = (args.pattern || "") as string;
      const rawPath = (args.path || ".") as string;
      return themeFg("muted", "grep ") + themeFg("accent", `/${pattern}/`) + themeFg("dim", ` in ${shortenPath(rawPath)}`);
    }
    default: {
      const argsStr = JSON.stringify(args);
      const preview = argsStr.length > 50 ? `${argsStr.slice(0, 50)}...` : argsStr;
      return themeFg("accent", toolName) + themeFg("dim", ` ${preview}`);
    }
  }
}

interface UsageStats {
  input: number;
  output: number;
  cacheRead: number;
  cacheWrite: number;
  cost: number;
  contextTokens: number;
  turns: number;
}

interface SingleResult {
  agent: string;
  agentSource: AgentSource;
  task: string;
  exitCode: number;
  messages: Message[];
  stderr: string;
  usage: UsageStats;
  model?: string;
  stopReason?: string;
  errorMessage?: string;
  step?: number;
}

interface SubagentDetails {
  mode: "single" | "parallel" | "chain";
  agentScope: AgentScope;
  bundledAgentsDir: string;
  userAgentsDir: string;
  projectAgentsDir: string | null;
  results: SingleResult[];
}

function getFinalOutput(messages: Message[]): string {
  for (let i = messages.length - 1; i >= 0; i--) {
    const message = messages[i];
    if (message.role !== "assistant") continue;

    for (const part of message.content) {
      if (part.type === "text") return part.text;
    }
  }
  return "";
}

type DisplayItem =
  | { type: "text"; text: string }
  | { type: "toolCall"; name: string; args: Record<string, unknown> };

function getDisplayItems(messages: Message[]): DisplayItem[] {
  const items: DisplayItem[] = [];

  for (const message of messages) {
    if (message.role !== "assistant") continue;

    for (const part of message.content) {
      if (part.type === "text") items.push({ type: "text", text: part.text });
      if (part.type === "toolCall") items.push({ type: "toolCall", name: part.name, args: part.arguments });
    }
  }

  return items;
}

async function mapWithConcurrencyLimit<TIn, TOut>(
  items: TIn[],
  concurrency: number,
  fn: (item: TIn, index: number) => Promise<TOut>,
): Promise<TOut[]> {
  if (items.length === 0) return [];

  const limit = Math.max(1, Math.min(concurrency, items.length));
  const results: TOut[] = new Array(items.length);
  let nextIndex = 0;

  const workers = new Array(limit).fill(null).map(async () => {
    while (true) {
      const current = nextIndex++;
      if (current >= items.length) return;
      results[current] = await fn(items[current], current);
    }
  });

  await Promise.all(workers);
  return results;
}

async function writePromptToTempFile(agentName: string, prompt: string): Promise<{ dir: string; filePath: string }> {
  const tmpDir = await fs.promises.mkdtemp(path.join(os.tmpdir(), "pi-subagent-"));
  const safeName = agentName.replace(/[^\w.-]+/g, "_");
  const filePath = path.join(tmpDir, `prompt-${safeName}.md`);

  await withFileMutationQueue(filePath, async () => {
    await fs.promises.writeFile(filePath, prompt, { encoding: "utf-8", mode: 0o600 });
  });

  return { dir: tmpDir, filePath };
}

function getPiInvocation(args: string[]): { command: string; args: string[] } {
  const currentScript = process.argv[1];
  if (currentScript && fs.existsSync(currentScript)) {
    return { command: process.execPath, args: [currentScript, ...args] };
  }

  const execName = path.basename(process.execPath).toLowerCase();
  const isGenericRuntime = /^(node|bun)(\.exe)?$/.test(execName);
  if (!isGenericRuntime) {
    return { command: process.execPath, args };
  }

  return { command: "pi", args };
}

type OnUpdateCallback = (partial: AgentToolResult<SubagentDetails>) => void;

async function runSingleAgent(
  defaultCwd: string,
  agents: AgentConfig[],
  agentName: string,
  task: string,
  cwd: string | undefined,
  step: number | undefined,
  signal: AbortSignal | undefined,
  onUpdate: OnUpdateCallback | undefined,
  makeDetails: (results: SingleResult[]) => SubagentDetails,
): Promise<SingleResult> {
  const agent = agents.find((entry) => entry.name === agentName);

  if (!agent) {
    const available = agents.map((entry) => `"${entry.name}"`).join(", ") || "none";
    return {
      agent: agentName,
      agentSource: "unknown",
      task,
      exitCode: 1,
      messages: [],
      stderr: `Unknown agent: "${agentName}". Available agents: ${available}.`,
      usage: { input: 0, output: 0, cacheRead: 0, cacheWrite: 0, cost: 0, contextTokens: 0, turns: 0 },
      step,
    };
  }

  const args: string[] = ["--mode", "json", "-p", "--no-session"];
  if (agent.model) args.push("--model", agent.model);
  if (agent.tools && agent.tools.length > 0) args.push("--tools", agent.tools.join(","));

  let tmpPromptDir: string | null = null;
  let tmpPromptPath: string | null = null;

  const currentResult: SingleResult = {
    agent: agentName,
    agentSource: agent.source,
    task,
    exitCode: 0,
    messages: [],
    stderr: "",
    usage: { input: 0, output: 0, cacheRead: 0, cacheWrite: 0, cost: 0, contextTokens: 0, turns: 0 },
    model: agent.model,
    step,
  };

  const emitUpdate = () => {
    if (!onUpdate) return;
    onUpdate({
      content: [{ type: "text", text: getFinalOutput(currentResult.messages) || "(running...)" }],
      details: makeDetails([currentResult]),
    });
  };

  try {
    if (agent.systemPrompt.trim()) {
      const tmp = await writePromptToTempFile(agent.name, agent.systemPrompt);
      tmpPromptDir = tmp.dir;
      tmpPromptPath = tmp.filePath;
      args.push("--append-system-prompt", tmpPromptPath);
    }

    args.push(`Task: ${task}`);
    let wasAborted = false;

    const exitCode = await new Promise<number>((resolve) => {
      const invocation = getPiInvocation(args);
      const proc = spawn(invocation.command, invocation.args, {
        cwd: cwd ?? defaultCwd,
        shell: false,
        stdio: ["ignore", "pipe", "pipe"],
      });

      let buffer = "";

      const processLine = (line: string) => {
        if (!line.trim()) return;

        let event: any;
        try {
          event = JSON.parse(line);
        } catch {
          return;
        }

        if (event.type === "message_end" && event.message) {
          const message = event.message as Message;
          currentResult.messages.push(message);

          if (message.role === "assistant") {
            currentResult.usage.turns++;
            const usage = message.usage;
            if (usage) {
              currentResult.usage.input += usage.input || 0;
              currentResult.usage.output += usage.output || 0;
              currentResult.usage.cacheRead += usage.cacheRead || 0;
              currentResult.usage.cacheWrite += usage.cacheWrite || 0;
              currentResult.usage.cost += usage.cost?.total || 0;
              currentResult.usage.contextTokens = usage.totalTokens || 0;
            }
            if (!currentResult.model && message.model) currentResult.model = message.model;
            if (message.stopReason) currentResult.stopReason = message.stopReason;
            if (message.errorMessage) currentResult.errorMessage = message.errorMessage;
          }

          emitUpdate();
        }

        if (event.type === "tool_result_end" && event.message) {
          currentResult.messages.push(event.message as Message);
          emitUpdate();
        }
      };

      proc.stdout.on("data", (data) => {
        buffer += data.toString();
        const lines = buffer.split("\n");
        buffer = lines.pop() || "";
        for (const line of lines) processLine(line);
      });

      proc.stderr.on("data", (data) => {
        currentResult.stderr += data.toString();
      });

      proc.on("close", (code) => {
        if (buffer.trim()) processLine(buffer);
        resolve(code ?? 0);
      });

      proc.on("error", () => {
        resolve(1);
      });

      if (signal) {
        const killProc = () => {
          wasAborted = true;
          proc.kill("SIGTERM");
          setTimeout(() => {
            if (!proc.killed) proc.kill("SIGKILL");
          }, 5000);
        };

        if (signal.aborted) killProc();
        else signal.addEventListener("abort", killProc, { once: true });
      }
    });

    currentResult.exitCode = exitCode;
    if (wasAborted) throw new Error("Subagent was aborted");
    return currentResult;
  } finally {
    if (tmpPromptPath) {
      try {
        fs.unlinkSync(tmpPromptPath);
      } catch {
        // ignore cleanup errors
      }
    }

    if (tmpPromptDir) {
      try {
        fs.rmdirSync(tmpPromptDir);
      } catch {
        // ignore cleanup errors
      }
    }
  }
}

const TaskItem = Type.Object({
  agent: Type.String({ description: "Name of the agent to invoke" }),
  task: Type.String({ description: "Task to delegate to the agent" }),
  cwd: Type.Optional(Type.String({ description: "Working directory for the agent process" })),
});

const ChainItem = Type.Object({
  agent: Type.String({ description: "Name of the agent to invoke" }),
  task: Type.String({ description: "Task with optional {previous} placeholder for prior output" }),
  cwd: Type.Optional(Type.String({ description: "Working directory for the agent process" })),
});

const AgentScopeSchema = StringEnum(["global", "project", "both"] as const, {
  description:
    'Which agent directories to use. Default: "global". Global includes bundled agents from this extension plus ~/.pi/agent/agents. Use "both" to include project-local .pi/agents.',
  default: "global",
});

const SubagentParams = Type.Object({
  agent: Type.Optional(Type.String({ description: "Name of the agent to invoke (single mode)" })),
  task: Type.Optional(Type.String({ description: "Task to delegate (single mode)" })),
  tasks: Type.Optional(Type.Array(TaskItem, { description: "Array of {agent, task} for parallel execution" })),
  chain: Type.Optional(Type.Array(ChainItem, { description: "Array of {agent, task} for sequential execution" })),
  agentScope: Type.Optional(AgentScopeSchema),
  confirmProjectAgents: Type.Optional(
    Type.Boolean({ description: "Prompt before running project-local agents. Default: true.", default: true }),
  ),
  cwd: Type.Optional(Type.String({ description: "Working directory for the agent process (single mode)" })),
});

function buildDiscoveryNotes(discovery: ReturnType<typeof discoverAgents>): string[] {
  const lines = [
    `Bundled: ${discovery.bundledAgentsDir}`,
    `User: ${discovery.userAgentsDir}`,
    `Project: ${discovery.projectAgentsDir ?? "(not found)"}`,
  ];
  return lines;
}

export default function (pi: ExtensionAPI) {
  pi.on("resources_discover", async () => {
    if (!fs.existsSync(BUNDLED_PROMPTS_DIR)) return;
    return { promptPaths: [BUNDLED_PROMPTS_DIR] };
  });

  pi.registerCommand("subagents", {
    description: "List available subagents and their sources",
    handler: async (args, ctx) => {
      const requestedScope = args?.trim();
      const agentScope: AgentScope =
        requestedScope === "project" || requestedScope === "both" || requestedScope === "global"
          ? requestedScope
          : "global";
      const discovery = discoverAgents(ctx.cwd, agentScope);
      const lines = [
        `Subagents [${agentScope}]`,
        ...buildDiscoveryNotes(discovery),
        "",
      ];

      if (discovery.agents.length === 0) {
        lines.push("No agents found.");
      } else {
        for (const agent of discovery.agents) {
          const parallelMode = agent.parallelSafe ? "parallel-safe" : "serial-only";
          const model = agent.model ?? "(default model)";
          const tools = agent.tools?.join(", ") ?? "(default tools)";
          lines.push(`- ${agent.name} [${agent.source}]`);
          lines.push(`  role: ${agent.role ?? "(unspecified)"}`);
          lines.push(`  mode: ${parallelMode}`);
          lines.push(`  model: ${model}`);
          lines.push(`  tools: ${tools}`);
          lines.push(`  file: ${agent.filePath}`);
          lines.push(`  description: ${agent.description}`);
          if (agent.tags && agent.tags.length > 0) lines.push(`  tags: ${agent.tags.join(", ")}`);
          lines.push("");
        }
      }

      if (ctx.hasUI) {
        ctx.ui.setEditorText(lines.join("\n").trim());
        ctx.ui.notify(`Loaded ${discovery.agents.length} subagent(s)`, "info");
      } else {
        console.log(lines.join("\n"));
      }
    },
  });

  pi.registerTool({
    name: "subagent",
    label: "Subagent",
    description: [
      "Delegate tasks to specialized subagents with isolated context windows.",
      "Modes: single (agent + task), parallel (tasks array), chain (sequential with {previous} placeholder).",
      'Default agent scope is "global" (bundled extension agents plus ~/.pi/agent/agents).',
      'To enable project-local agents in .pi/agents, set agentScope: "both" (or "project").',
      "Parallel mode is intended for read-only or explicitly parallel-safe agents.",
    ].join(" "),
    promptSnippet: "Delegate recon, planning, implementation, review, or librarian tasks to specialized subagents.",
    promptGuidelines: [
      "Use parallel subagents for independent read/search/review tasks.",
      "Do not run implementation agents in parallel unless the agent is explicitly marked safe for parallel use.",
      "Use chain mode for scout -> planner -> implementer or implementer -> reviewer handoffs.",
    ],
    parameters: SubagentParams,

    async execute(_toolCallId, params, signal, onUpdate, ctx) {
      const agentScope: AgentScope = params.agentScope ?? "global";
      const discovery = discoverAgents(ctx.cwd, agentScope);
      const agents = discovery.agents;
      const confirmProjectAgents = params.confirmProjectAgents ?? true;

      const hasChain = (params.chain?.length ?? 0) > 0;
      const hasTasks = (params.tasks?.length ?? 0) > 0;
      const hasSingle = Boolean(params.agent && params.task);
      const modeCount = Number(hasChain) + Number(hasTasks) + Number(hasSingle);

      const makeDetails =
        (mode: "single" | "parallel" | "chain") =>
        (results: SingleResult[]): SubagentDetails => ({
          mode,
          agentScope,
          bundledAgentsDir: discovery.bundledAgentsDir,
          userAgentsDir: discovery.userAgentsDir,
          projectAgentsDir: discovery.projectAgentsDir,
          results,
        });

      if (modeCount !== 1) {
        const { text, remaining } = formatAgentList(agents, 8);
        const suffix = remaining > 0 ? ` (+${remaining} more)` : "";
        return {
          content: [{ type: "text", text: `Invalid parameters. Provide exactly one mode. Available agents: ${text}${suffix}` }],
          details: makeDetails("single")([]),
        };
      }

      if ((agentScope === "project" || agentScope === "both") && confirmProjectAgents && ctx.hasUI) {
        const requestedAgentNames = new Set<string>();
        if (params.chain) for (const step of params.chain) requestedAgentNames.add(step.agent);
        if (params.tasks) for (const task of params.tasks) requestedAgentNames.add(task.agent);
        if (params.agent) requestedAgentNames.add(params.agent);

        const projectAgentsRequested = Array.from(requestedAgentNames)
          .map((name) => agents.find((entry) => entry.name === name))
          .filter((entry): entry is AgentConfig => entry?.source === "project");

        if (projectAgentsRequested.length > 0) {
          const names = projectAgentsRequested.map((entry) => entry.name).join(", ");
          const dir = discovery.projectAgentsDir ?? "(unknown)";
          const ok = await ctx.ui.confirm(
            "Run project-local agents?",
            `Agents: ${names}\nSource: ${dir}\n\nProject agents are repo-controlled. Only continue for trusted repositories.`,
          );

          if (!ok) {
            return {
              content: [{ type: "text", text: "Canceled: project-local agents not approved." }],
              details: makeDetails(hasChain ? "chain" : hasTasks ? "parallel" : "single")([]),
            };
          }
        }
      }

      if (params.chain && params.chain.length > 0) {
        const results: SingleResult[] = [];
        let previousOutput = "";

        for (let i = 0; i < params.chain.length; i++) {
          const step = params.chain[i];
          const taskWithContext = step.task.replace(/\{previous\}/g, previousOutput);

          const chainUpdate: OnUpdateCallback | undefined = onUpdate
            ? (partial) => {
                const currentResult = partial.details?.results[0];
                if (!currentResult) return;
                onUpdate({
                  content: partial.content,
                  details: makeDetails("chain")([...results, currentResult]),
                });
              }
            : undefined;

          const result = await runSingleAgent(
            ctx.cwd,
            agents,
            step.agent,
            taskWithContext,
            step.cwd,
            i + 1,
            signal,
            chainUpdate,
            makeDetails("chain"),
          );
          results.push(result);

          const isError =
            result.exitCode !== 0 || result.stopReason === "error" || result.stopReason === "aborted";
          if (isError) {
            const errorMessage = result.errorMessage || result.stderr || getFinalOutput(result.messages) || "(no output)";
            return {
              content: [{ type: "text", text: `Chain stopped at step ${i + 1} (${step.agent}): ${errorMessage}` }],
              details: makeDetails("chain")(results),
            };
          }

          previousOutput = getFinalOutput(result.messages);
        }

        return {
          content: [{ type: "text", text: getFinalOutput(results[results.length - 1].messages) || "(no output)" }],
          details: makeDetails("chain")(results),
        };
      }

      if (params.tasks && params.tasks.length > 0) {
        if (params.tasks.length > MAX_PARALLEL_TASKS) {
          return {
            content: [{ type: "text", text: `Too many parallel tasks (${params.tasks.length}). Max is ${MAX_PARALLEL_TASKS}.` }],
            details: makeDetails("parallel")([]),
          };
        }

        const unsafeAgents = Array.from(new Set(params.tasks.map((task) => task.agent)))
          .map((name) => agents.find((entry) => entry.name === name))
          .filter((entry): entry is AgentConfig => Boolean(entry && !entry.parallelSafe));

        if (unsafeAgents.length > 0) {
          const names = unsafeAgents.map((entry) => `${entry.name} [${entry.source}]`).join(", ");
          return {
            content: [{ type: "text", text: `Parallel mode blocked. These agents are serial-only: ${names}.` }],
            details: makeDetails("parallel")([]),
          };
        }

        const allResults: SingleResult[] = new Array(params.tasks.length);
        for (let i = 0; i < params.tasks.length; i++) {
          allResults[i] = {
            agent: params.tasks[i].agent,
            agentSource: "unknown",
            task: params.tasks[i].task,
            exitCode: -1,
            messages: [],
            stderr: "",
            usage: { input: 0, output: 0, cacheRead: 0, cacheWrite: 0, cost: 0, contextTokens: 0, turns: 0 },
          };
        }

        const emitParallelUpdate = () => {
          if (!onUpdate) return;
          const running = allResults.filter((result) => result.exitCode === -1).length;
          const done = allResults.filter((result) => result.exitCode !== -1).length;
          onUpdate({
            content: [{ type: "text", text: `Parallel: ${done}/${allResults.length} done, ${running} running...` }],
            details: makeDetails("parallel")([...allResults]),
          });
        };

        const results = await mapWithConcurrencyLimit(params.tasks, MAX_CONCURRENCY, async (task, index) => {
          const result = await runSingleAgent(
            ctx.cwd,
            agents,
            task.agent,
            task.task,
            task.cwd,
            undefined,
            signal,
            (partial) => {
              if (!partial.details?.results[0]) return;
              allResults[index] = partial.details.results[0];
              emitParallelUpdate();
            },
            makeDetails("parallel"),
          );
          allResults[index] = result;
          emitParallelUpdate();
          return result;
        });

        const successCount = results.filter((result) => result.exitCode === 0).length;
        const summaries = results.map((result) => {
          const output = getFinalOutput(result.messages);
          const preview = output.slice(0, 100) + (output.length > 100 ? "..." : "");
          return `[${result.agent}] ${result.exitCode === 0 ? "completed" : "failed"}: ${preview || "(no output)"}`;
        });

        return {
          content: [{ type: "text", text: `Parallel: ${successCount}/${results.length} succeeded\n\n${summaries.join("\n\n")}` }],
          details: makeDetails("parallel")(results),
        };
      }

      if (params.agent && params.task) {
        const result = await runSingleAgent(
          ctx.cwd,
          agents,
          params.agent,
          params.task,
          params.cwd,
          undefined,
          signal,
          onUpdate,
          makeDetails("single"),
        );

        const isError = result.exitCode !== 0 || result.stopReason === "error" || result.stopReason === "aborted";
        if (isError) {
          const errorMessage = result.errorMessage || result.stderr || getFinalOutput(result.messages) || "(no output)";
          return {
            content: [{ type: "text", text: `Agent ${result.stopReason || "failed"}: ${errorMessage}` }],
            details: makeDetails("single")([result]),
          };
        }

        return {
          content: [{ type: "text", text: getFinalOutput(result.messages) || "(no output)" }],
          details: makeDetails("single")([result]),
        };
      }

      const { text, remaining } = formatAgentList(agents, 8);
      const suffix = remaining > 0 ? ` (+${remaining} more)` : "";
      return {
        content: [{ type: "text", text: `Invalid parameters. Available agents: ${text}${suffix}` }],
        details: makeDetails("single")([]),
      };
    },

    renderCall(args, theme) {
      const scope: AgentScope = args.agentScope ?? "global";

      if (args.chain && args.chain.length > 0) {
        let text =
          theme.fg("toolTitle", theme.bold("subagent ")) +
          theme.fg("accent", `chain (${args.chain.length} steps)`) +
          theme.fg("muted", ` [${scope}]`);
        for (let i = 0; i < Math.min(args.chain.length, 3); i++) {
          const step = args.chain[i];
          const cleanTask = step.task.replace(/\{previous\}/g, "").trim();
          const preview = cleanTask.length > 40 ? `${cleanTask.slice(0, 40)}...` : cleanTask;
          text += `\n  ${theme.fg("muted", `${i + 1}.`)} ${theme.fg("accent", step.agent)}${theme.fg("dim", ` ${preview}`)}`;
        }
        if (args.chain.length > 3) text += `\n  ${theme.fg("muted", `... +${args.chain.length - 3} more`)}`;
        return new Text(text, 0, 0);
      }

      if (args.tasks && args.tasks.length > 0) {
        let text =
          theme.fg("toolTitle", theme.bold("subagent ")) +
          theme.fg("accent", `parallel (${args.tasks.length} tasks)`) +
          theme.fg("muted", ` [${scope}]`);
        for (const task of args.tasks.slice(0, 3)) {
          const preview = task.task.length > 40 ? `${task.task.slice(0, 40)}...` : task.task;
          text += `\n  ${theme.fg("accent", task.agent)}${theme.fg("dim", ` ${preview}`)}`;
        }
        if (args.tasks.length > 3) text += `\n  ${theme.fg("muted", `... +${args.tasks.length - 3} more`)}`;
        return new Text(text, 0, 0);
      }

      const agentName = args.agent || "...";
      const preview = args.task ? (args.task.length > 60 ? `${args.task.slice(0, 60)}...` : args.task) : "...";
      let text =
        theme.fg("toolTitle", theme.bold("subagent ")) +
        theme.fg("accent", agentName) +
        theme.fg("muted", ` [${scope}]`);
      text += `\n  ${theme.fg("dim", preview)}`;
      return new Text(text, 0, 0);
    },

    renderResult(result, { expanded }, theme) {
      const details = result.details as SubagentDetails | undefined;
      if (!details || details.results.length === 0) {
        const text = result.content[0];
        return new Text(text?.type === "text" ? text.text : "(no output)", 0, 0);
      }

      const mdTheme = getMarkdownTheme();

      const renderDisplayItems = (items: DisplayItem[], limit?: number) => {
        const toShow = limit ? items.slice(-limit) : items;
        const skipped = limit && items.length > limit ? items.length - limit : 0;
        let text = "";
        if (skipped > 0) text += theme.fg("muted", `... ${skipped} earlier items\n`);
        for (const item of toShow) {
          if (item.type === "text") {
            const preview = expanded ? item.text : item.text.split("\n").slice(0, 3).join("\n");
            text += `${theme.fg("toolOutput", preview)}\n`;
          } else {
            text += `${theme.fg("muted", "→ ") + formatToolCall(item.name, item.args, theme.fg.bind(theme))}\n`;
          }
        }
        return text.trimEnd();
      };

      if (details.mode === "single" && details.results.length === 1) {
        const entry = details.results[0];
        const isError = entry.exitCode !== 0 || entry.stopReason === "error" || entry.stopReason === "aborted";
        const icon = isError ? theme.fg("error", "✗") : theme.fg("success", "✓");
        const displayItems = getDisplayItems(entry.messages);
        const finalOutput = getFinalOutput(entry.messages);

        if (expanded) {
          const container = new Container();
          let header = `${icon} ${theme.fg("toolTitle", theme.bold(entry.agent))}${theme.fg("muted", ` (${entry.agentSource})`)}`;
          if (isError && entry.stopReason) header += ` ${theme.fg("error", `[${entry.stopReason}]`)}`;
          container.addChild(new Text(header, 0, 0));
          if (isError && entry.errorMessage) container.addChild(new Text(theme.fg("error", `Error: ${entry.errorMessage}`), 0, 0));
          container.addChild(new Spacer(1));
          container.addChild(new Text(theme.fg("muted", "─── Task ───"), 0, 0));
          container.addChild(new Text(theme.fg("dim", entry.task), 0, 0));
          container.addChild(new Spacer(1));
          container.addChild(new Text(theme.fg("muted", "─── Output ───"), 0, 0));
          if (displayItems.length === 0 && !finalOutput) {
            container.addChild(new Text(theme.fg("muted", "(no output)"), 0, 0));
          } else {
            for (const item of displayItems) {
              if (item.type === "toolCall") {
                container.addChild(
                  new Text(theme.fg("muted", "→ ") + formatToolCall(item.name, item.args, theme.fg.bind(theme)), 0, 0),
                );
              }
            }
            if (finalOutput) {
              container.addChild(new Spacer(1));
              container.addChild(new Markdown(finalOutput.trim(), 0, 0, mdTheme));
            }
          }
          const usageText = formatUsageStats(entry.usage, entry.model);
          if (usageText) {
            container.addChild(new Spacer(1));
            container.addChild(new Text(theme.fg("dim", usageText), 0, 0));
          }
          return container;
        }

        let text = `${icon} ${theme.fg("toolTitle", theme.bold(entry.agent))}${theme.fg("muted", ` (${entry.agentSource})`)}`;
        if (isError && entry.stopReason) text += ` ${theme.fg("error", `[${entry.stopReason}]`)}`;
        if (isError && entry.errorMessage) {
          text += `\n${theme.fg("error", `Error: ${entry.errorMessage}`)}`;
        } else if (displayItems.length === 0) {
          text += `\n${theme.fg("muted", "(no output)")}`;
        } else {
          text += `\n${renderDisplayItems(displayItems, COLLAPSED_ITEM_COUNT)}`;
          if (displayItems.length > COLLAPSED_ITEM_COUNT) text += `\n${theme.fg("muted", "(Ctrl+O to expand)")}`;
        }
        const usageText = formatUsageStats(entry.usage, entry.model);
        if (usageText) text += `\n${theme.fg("dim", usageText)}`;
        return new Text(text, 0, 0);
      }

      const aggregateUsage = (entries: SingleResult[]) => {
        const total = { input: 0, output: 0, cacheRead: 0, cacheWrite: 0, cost: 0, turns: 0 };
        for (const entry of entries) {
          total.input += entry.usage.input;
          total.output += entry.usage.output;
          total.cacheRead += entry.usage.cacheRead;
          total.cacheWrite += entry.usage.cacheWrite;
          total.cost += entry.usage.cost;
          total.turns += entry.usage.turns;
        }
        return total;
      };

      if (details.mode === "chain") {
        const successCount = details.results.filter((entry) => entry.exitCode === 0).length;
        const icon = successCount === details.results.length ? theme.fg("success", "✓") : theme.fg("error", "✗");

        if (expanded) {
          const container = new Container();
          container.addChild(
            new Text(
              `${icon} ${theme.fg("toolTitle", theme.bold("chain "))}${theme.fg("accent", `${successCount}/${details.results.length} steps`)}`,
              0,
              0,
            ),
          );

          for (const entry of details.results) {
            const entryIcon = entry.exitCode === 0 ? theme.fg("success", "✓") : theme.fg("error", "✗");
            const displayItems = getDisplayItems(entry.messages);
            const finalOutput = getFinalOutput(entry.messages);

            container.addChild(new Spacer(1));
            container.addChild(
              new Text(`${theme.fg("muted", `─── Step ${entry.step}: `)}${theme.fg("accent", entry.agent)} ${entryIcon}`, 0, 0),
            );
            container.addChild(new Text(theme.fg("muted", "Task: ") + theme.fg("dim", entry.task), 0, 0));

            for (const item of displayItems) {
              if (item.type === "toolCall") {
                container.addChild(
                  new Text(theme.fg("muted", "→ ") + formatToolCall(item.name, item.args, theme.fg.bind(theme)), 0, 0),
                );
              }
            }

            if (finalOutput) {
              container.addChild(new Spacer(1));
              container.addChild(new Markdown(finalOutput.trim(), 0, 0, mdTheme));
            }

            const usageText = formatUsageStats(entry.usage, entry.model);
            if (usageText) container.addChild(new Text(theme.fg("dim", usageText), 0, 0));
          }

          const usageText = formatUsageStats(aggregateUsage(details.results));
          if (usageText) {
            container.addChild(new Spacer(1));
            container.addChild(new Text(theme.fg("dim", `Total: ${usageText}`), 0, 0));
          }
          return container;
        }

        let text = `${icon} ${theme.fg("toolTitle", theme.bold("chain "))}${theme.fg("accent", `${successCount}/${details.results.length} steps`)}`;
        for (const entry of details.results) {
          const entryIcon = entry.exitCode === 0 ? theme.fg("success", "✓") : theme.fg("error", "✗");
          const displayItems = getDisplayItems(entry.messages);
          text += `\n\n${theme.fg("muted", `─── Step ${entry.step}: `)}${theme.fg("accent", entry.agent)} ${entryIcon}`;
          if (displayItems.length === 0) text += `\n${theme.fg("muted", "(no output)")}`;
          else text += `\n${renderDisplayItems(displayItems, 5)}`;
        }
        const usageText = formatUsageStats(aggregateUsage(details.results));
        if (usageText) text += `\n\n${theme.fg("dim", `Total: ${usageText}`)}`;
        text += `\n${theme.fg("muted", "(Ctrl+O to expand)")}`;
        return new Text(text, 0, 0);
      }

      if (details.mode === "parallel") {
        const running = details.results.filter((entry) => entry.exitCode === -1).length;
        const successCount = details.results.filter((entry) => entry.exitCode === 0).length;
        const failCount = details.results.filter((entry) => entry.exitCode > 0).length;
        const isRunning = running > 0;
        const icon = isRunning
          ? theme.fg("warning", "⏳")
          : failCount > 0
            ? theme.fg("warning", "◐")
            : theme.fg("success", "✓");
        const status = isRunning
          ? `${successCount + failCount}/${details.results.length} done, ${running} running`
          : `${successCount}/${details.results.length} tasks`;

        if (expanded && !isRunning) {
          const container = new Container();
          container.addChild(
            new Text(`${icon} ${theme.fg("toolTitle", theme.bold("parallel "))}${theme.fg("accent", status)}`, 0, 0),
          );

          for (const entry of details.results) {
            const entryIcon = entry.exitCode === 0 ? theme.fg("success", "✓") : theme.fg("error", "✗");
            const displayItems = getDisplayItems(entry.messages);
            const finalOutput = getFinalOutput(entry.messages);

            container.addChild(new Spacer(1));
            container.addChild(new Text(`${theme.fg("muted", "─── ")}${theme.fg("accent", entry.agent)} ${entryIcon}`, 0, 0));
            container.addChild(new Text(theme.fg("muted", "Task: ") + theme.fg("dim", entry.task), 0, 0));

            for (const item of displayItems) {
              if (item.type === "toolCall") {
                container.addChild(
                  new Text(theme.fg("muted", "→ ") + formatToolCall(item.name, item.args, theme.fg.bind(theme)), 0, 0),
                );
              }
            }

            if (finalOutput) {
              container.addChild(new Spacer(1));
              container.addChild(new Markdown(finalOutput.trim(), 0, 0, mdTheme));
            }

            const usageText = formatUsageStats(entry.usage, entry.model);
            if (usageText) container.addChild(new Text(theme.fg("dim", usageText), 0, 0));
          }

          const usageText = formatUsageStats(aggregateUsage(details.results));
          if (usageText) {
            container.addChild(new Spacer(1));
            container.addChild(new Text(theme.fg("dim", `Total: ${usageText}`), 0, 0));
          }
          return container;
        }

        let text = `${icon} ${theme.fg("toolTitle", theme.bold("parallel "))}${theme.fg("accent", status)}`;
        for (const entry of details.results) {
          const entryIcon =
            entry.exitCode === -1
              ? theme.fg("warning", "⏳")
              : entry.exitCode === 0
                ? theme.fg("success", "✓")
                : theme.fg("error", "✗");
          const displayItems = getDisplayItems(entry.messages);
          text += `\n\n${theme.fg("muted", "─── ")}${theme.fg("accent", entry.agent)} ${entryIcon}`;
          if (displayItems.length === 0) {
            text += `\n${theme.fg("muted", entry.exitCode === -1 ? "(running...)" : "(no output)")}`;
          } else {
            text += `\n${renderDisplayItems(displayItems, 5)}`;
          }
        }
        if (!isRunning) {
          const usageText = formatUsageStats(aggregateUsage(details.results));
          if (usageText) text += `\n\n${theme.fg("dim", `Total: ${usageText}`)}`;
        }
        if (!expanded) text += `\n${theme.fg("muted", "(Ctrl+O to expand)")}`;
        return new Text(text, 0, 0);
      }

      const text = result.content[0];
      return new Text(text?.type === "text" ? text.text : "(no output)", 0, 0);
    },
  });
}
