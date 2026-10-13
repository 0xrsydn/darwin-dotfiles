const assert = require("node:assert/strict");
const { spawn } = require("node:child_process");
const { once } = require("node:events");
const fs = require("node:fs");
const http = require("node:http");
const os = require("node:os");
const path = require("node:path");
const test = require("node:test");
const zlib = require("node:zlib");

test("installed Pi sends priority only for Codex and restores session state", { timeout: 60000 }, async () => {
  const dir = fs.mkdtempSync(path.join(os.tmpdir(), "pi-codex-fast-test-"));
  const requests = [];
  let holdNextResponse;
  const server = http.createServer(async (req, res) => {
    try {
      const chunks = [];
      for await (const chunk of req) chunks.push(chunk);
      let bytes = Buffer.concat(chunks);
      if (req.headers["content-encoding"] === "zstd") bytes = zlib.zstdDecompressSync(bytes);
      requests.push(JSON.parse(bytes.toString()));
      const held = holdNextResponse;
      holdNextResponse = undefined;
      server.emit("fixture_request");
      if (held) await held;
      res.writeHead(200, { "Content-Type": "text/event-stream" });
      const response = {
        id: "resp_fixture", status: "completed", output: [],
        usage: { input_tokens: 10, output_tokens: 0, total_tokens: 10, input_tokens_details: { cached_tokens: 0 } },
      };
      res.end(`data: ${JSON.stringify({ type: "response.completed", response })}\n\n`);
    } catch (error) {
      res.writeHead(500);
      res.end(String(error));
    }
  });
  server.listen(0, "127.0.0.1");
  await once(server, "listening");
  const baseUrl = `http://127.0.0.1:${server.address().port}`;
  const token = `e30.${Buffer.from(JSON.stringify({ "https://api.openai.com/auth": { chatgpt_account_id: "fixture" } })).toString("base64")}.fixture`;
  const model = { id: "gpt-fast-fixture", reasoning: true, input: ["text"], contextWindow: 128000, maxTokens: 4096 };
  fs.writeFileSync(path.join(dir, "settings.json"), JSON.stringify({
    transport: "sse", compaction: { enabled: false }, retry: { enabled: false }, enableInstallTelemetry: false,
  }));
  fs.writeFileSync(path.join(dir, "models.json"), JSON.stringify({ providers: {
    "openai-codex": { baseUrl, api: "openai-codex-responses", apiKey: token, models: [model] },
    openai: { baseUrl, api: "openai-responses", apiKey: "fixture", models: [model] },
  } }));
  const child = spawn("pi", [
    "--offline", "--no-extensions", "--no-mcp", "--no-skills", "--no-prompt-templates", "--no-context-files",
    "-e", path.resolve(__dirname, "../index.ts"),
    "-e", path.resolve(__dirname, "../../openai-server-compaction/index.ts"),
    "--model", "openai-codex/gpt-fast-fixture", "--thinking", "high", "--no-tools", "--mode", "rpc",
  ], { cwd: dir, env: { ...process.env, PI_CODING_AGENT_DIR: dir } });
  let buffer = "", stderr = "", seq = 0;
  const events = [], waiters = new Set();
  child.stderr.on("data", chunk => { stderr += chunk; });
  child.stdout.on("data", chunk => {
    buffer += chunk;
    let newline;
    while ((newline = buffer.indexOf("\n")) !== -1) {
      const line = buffer.slice(0, newline);
      buffer = buffer.slice(newline + 1);
      let record;
      try { record = JSON.parse(line); } catch { continue; }
      events.push(record);
      for (const waiter of [...waiters]) if (waiter.predicate(record)) {
        waiters.delete(waiter);
        clearTimeout(waiter.timer);
        waiter.resolve(record);
      }
    }
  });
  function wait(predicate) {
    return new Promise((resolve, reject) => {
      const waiter = { predicate, resolve, timer: setTimeout(() => {
        waiters.delete(waiter);
        reject(new Error(`RPC timeout. stderr: ${stderr}`));
      }, 10000) };
      waiters.add(waiter);
    });
  }
  async function command(type, fields = {}) {
    const id = String(++seq);
    const pending = wait(record => record.type === "response" && record.id === id);
    child.stdin.write(JSON.stringify({ id, type, ...fields }) + "\n");
    const record = await pending;
    assert.equal(record.success, true, JSON.stringify(record));
    return record.data;
  }
  async function slash(message) {
    const start = events.length;
    await command("prompt", { message });
    return events.slice(start).filter(record => record.type === "extension_ui_request" && record.method === "notify").map(record => record.message).join("\n");
  }
  async function turn(message) {
    const start = events.length;
    const settled = wait(record => record.type === "agent_settled");
    await command("prompt", { message });
    await settled;
    const answer = events.slice(start).find(record => record.type === "message_end" && record.message?.role === "assistant");
    assert.equal(answer?.message.stopReason, "stop", JSON.stringify(answer));
    return requests.at(-1);
  }
  try {
    const commands = await command("get_commands");
    assert.ok(commands.commands.some(item => item.name === "fast"));
    assert.match(await slash("/fast status"), /off/);
    const first = await turn("BEFORE_FAST");
    assert.equal(first.service_tier, undefined);
    const sessionFile = (await command("get_state")).sessionFile;
    assert.match(await slash("/fast on"), /usage may increase/);
    const fast = await turn("FAST_REQUEST");
    assert.equal(fast.service_tier, "priority");
    assert.equal(fast.model, first.model);
    assert.deepEqual(fast.reasoning, first.reasoning);
    assert.match(await slash("/fast on extra"), /Usage:/);
    assert.match(await slash("/fast status"), /on, requesting priority/);
    await command("set_model", { provider: "openai", modelId: model.id });
    assert.equal((await turn("OTHER_PROVIDER")).service_tier, undefined);
    assert.match(await slash("/fast status"), /inactive/);
    await slash("/fast off");
    assert.match(await slash("/fast on"), /requires the openai-codex provider/);
    await command("set_model", { provider: "openai-codex", modelId: model.id });
    assert.equal((await turn("DISABLED")).service_tier, undefined);
    await slash("/fast");
    assert.equal((await turn("TOGGLED_ON")).service_tier, "priority");
    const snapshots = (await command("get_entries")).entries.filter(entry => entry.type === "custom" && entry.customType === "openai-codex-fast");
    assert.deepEqual(snapshots.map(entry => entry.data.enabled), [true, false, true]);
    let releaseResponse;
    holdNextResponse = new Promise(resolve => { releaseResponse = resolve; });
    const received = once(server, "fixture_request");
    const settled = wait(record => record.type === "agent_settled");
    await command("prompt", { message: "BUSY_TURN" });
    await received;
    try {
      assert.match(await slash("/fast off"), /Wait for the current turn/);
      assert.match(await slash("/fast status"), /on, requesting priority/);
    } finally {
      releaseResponse();
    }
    await settled;
    assert.match(await slash("/fast"), /off/);
    assert.match(await slash("/fast"), /on/);
    await command("new_session");
    assert.match(await slash("/fast status"), /off/);
    await command("switch_session", { sessionPath: sessionFile });
    assert.match(await slash("/fast status"), /on, requesting priority/);
    assert.equal((await turn("RESUMED")).service_tier, "priority");
    const forks = await command("get_fork_messages");
    await command("fork", { entryId: forks.messages.find(message => message.text === "BEFORE_FAST").entryId });
    assert.match(await slash("/fast status"), /off/);
    const entries = await command("get_entries");
    assert.ok(!entries.entries.some(entry => entry.type === "custom" && entry.customType === "openai-codex-fast"));
    assert.doesNotMatch(stderr, /Failed to load extension|Extension error/);
  } finally {
    for (const waiter of waiters) clearTimeout(waiter.timer);
    const closed = once(child, "close");
    child.stdin.end();
    const timer = setTimeout(() => child.kill("SIGKILL"), 3000);
    await closed;
    clearTimeout(timer);
    server.closeAllConnections();
    await new Promise(resolve => server.close(resolve));
    fs.rmSync(dir, { recursive: true, force: true });
  }
});
