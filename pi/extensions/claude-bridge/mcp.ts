/**
 * Minimal MCP streamable-HTTP server.
 *
 * Claude Code reaches pi's tools through this server. The provider passes a
 * `--mcp-config` entry pointing at `url`. A `tools/call` handler blocks until
 * pi delivers its tool result, which happens on the next `streamSimple` call.
 * That block is the whole trick: pi keeps ownership of tool execution and the
 * approval UI, while Claude Code still drives the turn.
 *
 * Only the parts Claude Code exercises are implemented: `initialize`,
 * `tools/list`, and `tools/call`. Claude Code also probes `server/discover`
 * first; it tolerates a method-not-found reply there, which is what it gets.
 * `GET` is answered 405 because this server never pushes notifications.
 *
 * Claude Code stamps every `tools/call` with the `tool_use` block id in
 * `params._meta["claudecode/toolUseId"]`. That is the only reliable pairing
 * key: call order does not have to match the order the tool_use blocks were
 * emitted. When the field is missing the call fails loudly instead of being
 * paired with the wrong result.
 */
import { createServer, type IncomingMessage, type ServerResponse } from "node:http";
import type { AddressInfo } from "node:net";

export type McpContent =
  | { type: "text"; text: string }
  | { type: "image"; data: string; mimeType: string };

export type McpResult = {
  content: McpContent[];
  isError?: boolean;
};

export type McpToolSchema = {
  name: string;
  description: string;
  inputSchema: unknown;
};

export type ToolServerOptions = {
  /** Read at `tools/list` time, so a live tool set needs no restart. */
  listTools: () => McpToolSchema[];
  callTool: (name: string, toolUseId: string) => Promise<McpResult>;
};

export type ToolServer = {
  url: string;
  close: () => Promise<void>;
};

export const TOOL_USE_ID_META = "claudecode/toolUseId";

const MCP_SESSION_ID = "pi-claude-bridge";
const PROTOCOL_VERSION = "2025-06-18";

function reply(res: ServerResponse, id: unknown, result: unknown): void {
  res.writeHead(200, {
    "content-type": "application/json",
    "mcp-session-id": MCP_SESSION_ID,
  });
  res.end(JSON.stringify({ jsonrpc: "2.0", id, result }));
}

function replyError(res: ServerResponse, id: unknown, code: number, message: string): void {
  res.writeHead(200, {
    "content-type": "application/json",
    "mcp-session-id": MCP_SESSION_ID,
  });
  res.end(JSON.stringify({ jsonrpc: "2.0", id, error: { code, message } }));
}

function readBody(req: IncomingMessage): Promise<string> {
  return new Promise((resolve, reject) => {
    let body = "";
    req.setEncoding("utf8");
    req.on("data", (chunk: string) => {
      body += chunk;
    });
    req.on("end", () => resolve(body));
    req.on("error", reject);
  });
}

export async function startToolServer(options: ToolServerOptions): Promise<ToolServer> {
  const server = createServer((req, res) => {
    void handle(req, res).catch(() => {
      if (!res.headersSent) res.writeHead(500);
      res.end();
    });
  });

  async function handle(req: IncomingMessage, res: ServerResponse): Promise<void> {
    if (req.method !== "POST") {
      res.writeHead(405).end();
      return;
    }

    let message: { id?: unknown; method?: string; params?: Record<string, any> };
    try {
      message = JSON.parse(await readBody(req));
    } catch {
      res.writeHead(400).end();
      return;
    }

    // JSON-RPC notification: acknowledge without a result body.
    if (message.id === undefined) {
      res.writeHead(202, { "mcp-session-id": MCP_SESSION_ID }).end();
      return;
    }

    const id = message.id;
    switch (message.method) {
      case "initialize":
        reply(res, id, {
          protocolVersion: PROTOCOL_VERSION,
          capabilities: { tools: {} },
          serverInfo: { name: "pi", version: "1" },
        });
        return;

      case "tools/list":
        reply(res, id, { tools: options.listTools() });
        return;

      case "tools/call": {
        const name = message.params?.name;
        if (typeof name !== "string") {
          replyError(res, id, -32602, "tools/call is missing a tool name");
          return;
        }
        const toolUseId = message.params?._meta?.[TOOL_USE_ID_META];
        if (typeof toolUseId !== "string") {
          replyError(res, id, -32602, `tools/call is missing _meta["${TOOL_USE_ID_META}"]`);
          return;
        }
        try {
          reply(res, id, await options.callTool(name, toolUseId));
        } catch (error) {
          reply(res, id, {
            content: [{ type: "text", text: error instanceof Error ? error.message : String(error) }],
            isError: true,
          });
        }
        return;
      }

      default:
        replyError(res, id, -32601, `Method not found: ${message.method}`);
    }
  }

  await new Promise<void>((resolve) => server.listen(0, "127.0.0.1", resolve));
  const { port } = server.address() as AddressInfo;

  return {
    url: `http://127.0.0.1:${port}/mcp`,
    close: () =>
      new Promise<void>((resolve) => {
        server.closeAllConnections?.();
        server.close(() => resolve());
      }),
  };
}
