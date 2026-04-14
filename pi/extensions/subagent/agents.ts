import * as fs from "node:fs";
import * as path from "node:path";
import { fileURLToPath } from "node:url";
import { getAgentDir, parseFrontmatter } from "@mariozechner/pi-coding-agent";

export type AgentScope = "global" | "project" | "both";
export type AgentSource = "bundled" | "user" | "project" | "unknown";

export interface AgentConfig {
  name: string;
  description: string;
  tools?: string[];
  model?: string;
  systemPrompt: string;
  source: AgentSource;
  filePath: string;
  parallelSafe: boolean;
  role?: string;
  tags?: string[];
}

export interface AgentDiscoveryResult {
  agents: AgentConfig[];
  bundledAgentsDir: string;
  userAgentsDir: string;
  projectAgentsDir: string | null;
}

function readString(value: unknown): string | undefined {
  return typeof value === "string" && value.trim() ? value.trim() : undefined;
}

function readBoolean(value: unknown): boolean | undefined {
  if (typeof value === "boolean") return value;
  if (typeof value === "number") return value !== 0;
  if (typeof value !== "string") return undefined;

  const normalized = value.trim().toLowerCase();
  if (["true", "yes", "on", "1"].includes(normalized)) return true;
  if (["false", "no", "off", "0"].includes(normalized)) return false;
  return undefined;
}

function readStringList(value: unknown): string[] | undefined {
  if (Array.isArray(value)) {
    const items = value
      .map((item) => (typeof item === "string" ? item.trim() : ""))
      .filter(Boolean);
    return items.length > 0 ? items : undefined;
  }

  if (typeof value === "string") {
    const items = value
      .split(",")
      .map((item) => item.trim())
      .filter(Boolean);
    return items.length > 0 ? items : undefined;
  }

  return undefined;
}

function isDirectory(pathname: string): boolean {
  try {
    return fs.statSync(pathname).isDirectory();
  } catch {
    return false;
  }
}

function getBundledAgentsDir(): string {
  return fileURLToPath(new URL("./agents", import.meta.url));
}

function getUserAgentsDir(): string {
  return path.join(getAgentDir(), "agents");
}

function findNearestProjectAgentsDir(cwd: string): string | null {
  let currentDir = cwd;
  while (true) {
    const candidate = path.join(currentDir, ".pi", "agents");
    if (isDirectory(candidate)) return candidate;

    const parentDir = path.dirname(currentDir);
    if (parentDir === currentDir) return null;
    currentDir = parentDir;
  }
}

function loadAgentsFromDir(dir: string, source: Exclude<AgentSource, "unknown">): AgentConfig[] {
  const agents: AgentConfig[] = [];

  if (!isDirectory(dir)) return agents;

  let entries: fs.Dirent[];
  try {
    entries = fs.readdirSync(dir, { withFileTypes: true });
  } catch {
    return agents;
  }

  for (const entry of entries) {
    if (!entry.name.endsWith(".md")) continue;
    if (!entry.isFile() && !entry.isSymbolicLink()) continue;

    const filePath = path.join(dir, entry.name);
    let content: string;
    try {
      content = fs.readFileSync(filePath, "utf-8");
    } catch {
      continue;
    }

    const { frontmatter, body } = parseFrontmatter<Record<string, unknown>>(content);
    const name = readString(frontmatter.name);
    const description = readString(frontmatter.description);

    if (!name || !description) continue;

    agents.push({
      name,
      description,
      tools: readStringList(frontmatter.tools),
      model: readString(frontmatter.model),
      systemPrompt: body.trim(),
      source,
      filePath,
      parallelSafe: readBoolean(frontmatter.parallelSafe) ?? false,
      role: readString(frontmatter.role),
      tags: readStringList(frontmatter.tags),
    });
  }

  return agents;
}

export function discoverAgents(cwd: string, scope: AgentScope): AgentDiscoveryResult {
  const bundledAgentsDir = getBundledAgentsDir();
  const userAgentsDir = getUserAgentsDir();
  const projectAgentsDir = findNearestProjectAgentsDir(cwd);

  const bundledAgents = loadAgentsFromDir(bundledAgentsDir, "bundled");
  const userAgents = scope === "project" ? [] : loadAgentsFromDir(userAgentsDir, "user");
  const projectAgents = scope === "global" || !projectAgentsDir ? [] : loadAgentsFromDir(projectAgentsDir, "project");

  const agentMap = new Map<string, AgentConfig>();

  if (scope === "global") {
    for (const agent of bundledAgents) agentMap.set(agent.name, agent);
    for (const agent of userAgents) agentMap.set(agent.name, agent);
  }

  if (scope === "project") {
    for (const agent of projectAgents) agentMap.set(agent.name, agent);
  }

  if (scope === "both") {
    for (const agent of bundledAgents) agentMap.set(agent.name, agent);
    for (const agent of userAgents) agentMap.set(agent.name, agent);
    for (const agent of projectAgents) agentMap.set(agent.name, agent);
  }

  return {
    agents: Array.from(agentMap.values()),
    bundledAgentsDir,
    userAgentsDir,
    projectAgentsDir,
  };
}

export function formatAgentList(agents: AgentConfig[], maxItems: number): { text: string; remaining: number } {
  if (agents.length === 0) return { text: "none", remaining: 0 };

  const listed = agents.slice(0, maxItems);
  const remaining = Math.max(0, agents.length - listed.length);
  const text = listed
    .map((agent) => {
      const mode = agent.parallelSafe ? "parallel" : "serial";
      const role = agent.role ? ` ${agent.role}` : "";
      return `${agent.name} (${agent.source}, ${mode}${role ? `, ${role}` : ""})`;
    })
    .join(", ");

  return { text, remaining };
}
