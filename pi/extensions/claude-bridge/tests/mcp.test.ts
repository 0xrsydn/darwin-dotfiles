import assert from "node:assert/strict";
import { test } from "node:test";
import { startToolServer, TOOL_USE_ID_META } from "../mcp.ts";

test("MCP initialization, notifications, validation, pairing, and tool errors", async () => {
  const calls: Array<{ name: string; id: string }> = [];
  let toolName = "read";
  const server = await startToolServer({
    listTools: () => [{ name: toolName, description: "Test tool", inputSchema: { type: "object" } }],
    callTool: async (name, id) => {
      calls.push({ name, id });
      if (name === "fail") throw new Error("EXPECTED_MCP_ERROR");
      return { content: [{ type: "text", text: id }] };
    },
  });
  async function rpc(method: string, params: Record<string, unknown> = {}) {
    const response = await fetch(server.url, {
      method: "POST", body: JSON.stringify({ jsonrpc: "2.0", id: 1, method, params }),
    });
    assert.equal(response.status, 200);
    return await response.json() as any;
  }
  try {
    assert.match(server.url, /^http:\/\/127\.0\.0\.1:/);
    assert.equal((await fetch(server.url)).status, 405);
    assert.equal((await fetch(server.url, { method: "POST", body: "not-json" })).status, 400);
    const notification = await fetch(server.url, {
      method: "POST", body: JSON.stringify({ jsonrpc: "2.0", method: "notifications/initialized" }),
    });
    assert.equal(notification.status, 202);
    assert.equal(await notification.text(), "");
    assert.equal((await rpc("initialize")).result.protocolVersion, "2025-06-18");
    assert.equal((await rpc("tools/list")).result.tools[0].name, "read");
    toolName = "changed";
    assert.equal((await rpc("tools/list")).result.tools[0].name, "changed");
    assert.equal((await rpc("server/discover")).error.code, -32601);
    assert.equal((await rpc("tools/call", {})).error.code, -32602);
    assert.equal((await rpc("tools/call", { name: "read" })).error.code, -32602);
    assert.equal(calls.length, 0);
    const result = await rpc("tools/call", { name: "read", _meta: { [TOOL_USE_ID_META]: "pair-73921" } });
    assert.equal(result.result.content[0].text, "pair-73921");
    assert.deepEqual(calls, [{ name: "read", id: "pair-73921" }]);
    const error = await rpc("tools/call", { name: "fail", _meta: { [TOOL_USE_ID_META]: "error-id" } });
    assert.equal(error.result.isError, true);
    assert.equal(error.result.content[0].text, "EXPECTED_MCP_ERROR");
  } finally {
    await server.close();
  }
});
