const assert = require('node:assert/strict');
const { spawn } = require('node:child_process');
const fs = require('node:fs');
const http = require('node:http');
const os = require('node:os');
const path = require('node:path');
const { test } = require('node:test');

// Runs the installed Pi provider runtime against a real local HTTP server.
// Only OMP's external CLI and upstream inference are fixtures; no paid requests.
test('native provider discovery, streaming, tools, usage, token rotation, and cache restoration', { timeout: 60000 }, async () => {
  const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'pi-omp-gateway-'));
  const tokenFile = path.join(dir, 'gateway.token');
  const metadataFile = path.join(dir, 'catalog.json');
  const fixture = path.join(dir, 'fixture.txt');
  const omp = path.join(dir, 'omp');
  const helper = path.join(dir, 'helper.ts');
  const defaultModel = { id: 'idle', name: 'Idle', reasoning: false, input: ['text'],
    cost: { input: 0, output: 0, cacheRead: 0, cacheWrite: 0 }, contextWindow: 32000, maxTokens: 1024 };
  fs.writeFileSync(tokenFile, 'test-token', { mode: 0o600 });
  fs.writeFileSync(fixture, 'LOCAL_FIXTURE_OK');
  const meta = { provider: 'cursor', kind: 'chat', id: 'grok-4.7', name: 'Grok 4.7', input: ['text', 'image'],
    reasoning: true, thinking: ['low', 'medium', 'high', 'xhigh'], contextWindow: 256000, maxTokens: 64000,
    cost: { input: 2, output: 6, cacheRead: 0.5, cacheWrite: 0 } };
  fs.writeFileSync(metadataFile, JSON.stringify({ models: [meta] }));
  const mockCli = path.join(dir, 'omp.cjs');
  fs.writeFileSync(mockCli, `const fs=require('node:fs');
    if (process.argv.slice(2).join(' ') !== 'models cursor --json --no-extensions') process.exit(2);
    if (process.env.PI_CONFIG_DIR !== '.omp-cursor' || process.env.PI_CODING_AGENT_DIR !== ${JSON.stringify(path.join(dir, 'cursor-agent'))} ||
        process.env.OMP_PROFILE !== '' || process.env.PI_PROFILE !== '' || process.env.PI_CONFIG_FILES !== '' ||
        process.env.OMP_AUTH_BROKER_URL || process.env.OMP_AUTH_BROKER_TOKEN) process.exit(3);
    process.stdout.write(fs.readFileSync(${JSON.stringify(metadataFile)},'utf8'));`);
  fs.writeFileSync(omp, `#!/bin/sh\nexec ${JSON.stringify(process.execPath)} ${JSON.stringify(mockCli)} "$@"\n`, { mode: 0o700 });
  let expectedToken = 'test-token';
  let catalogStatus = 200;
  let rows = [{ id: 'cursor/grok-4.7', owned_by: 'cursor', display_name: 'Grok 4.7', input_modalities: ['text', 'image'],
    context_length: 256000, max_output_tokens: 64000 }];
  const requests = [];
  const server = http.createServer(async (req, res) => {
    if (req.headers.authorization !== `Bearer ${expectedToken}`) {
      res.writeHead(401); res.end('DO_NOT_LOG_THIS_SECRET'); return;
    }
    if (req.url === '/v1/models') {
      res.writeHead(catalogStatus, { 'Content-Type': 'application/json' });
      res.end(JSON.stringify(catalogStatus === 200 ? { object: 'list', data: rows } : { error: 'DO_NOT_LOG_THIS_SECRET' }));
      return;
    }
    if (req.url !== '/v1/chat/completions') { res.writeHead(404); res.end(); return; }
    let raw = '';
    for await (const chunk of req) raw += chunk;
    const body = JSON.parse(raw);
    requests.push({ body, authorization: req.headers.authorization });
    res.writeHead(200, { 'Content-Type': 'text/event-stream' });
    const send = (delta, finish = null) => res.write(`data: ${JSON.stringify({ id: 'mock', object: 'chat.completion.chunk',
      model: body.model, choices: [{ index: 0, delta, finish_reason: finish }] })}\n\n`);
    send({ role: 'assistant' });
    const toolResult = body.messages.findLast(message => message.role === 'tool');
    const user = body.messages.findLast(message => message.role === 'user');
    const prompt = typeof user?.content === 'string' ? user.content :
      Array.isArray(user?.content) ? user.content.filter(block => block.type === 'text').map(block => block.text).join('') : '';
    if (prompt === 'USE_TOOL' && !toolResult) {
      send({ tool_calls: [{ index: 0, id: 'call_read', type: 'function', function: {
        name: 'read', arguments: JSON.stringify({ path: fixture }) } }] });
      send({}, 'tool_calls');
    } else {
      if (prompt !== 'EMPTY') send({ content: toolResult ? 'TOOL_OK' : 'Gateway ✓ Unicode 你好' });
      send({}, 'stop');
    }
    res.write(`data: ${JSON.stringify({ id: 'mock', choices: [], usage: {
      prompt_tokens: 100, completion_tokens: 4, total_tokens: 104, prompt_tokens_details: { cached_tokens: 10 } } })}\n\n`);
    res.end('data: [DONE]\n\n');
  });
  await new Promise(resolve => server.listen(0, '127.0.0.1', resolve));
  const baseUrl = `http://127.0.0.1:${server.address().port}/v1`;
  fs.writeFileSync(helper, `export default function(pi) { pi.registerProvider('gateway-test', {
    api: 'openai-completions', apiKey: 'test-token', baseUrl: ${JSON.stringify(baseUrl)}, models: [${JSON.stringify(defaultModel)}]
  }); }`);
  const children = [];
  const allStderr = [];
  function start() {
    const child = spawn('pi', ['--offline', '--no-extensions', '--no-mcp', '--no-skills', '--no-prompt-templates',
      '--no-context-files', '--no-session', '-e', path.resolve(__dirname, '../index.ts'), '-e', helper,
      '--model', 'gateway-test/idle', '--mode', 'rpc', '--tools', 'read'], {
      env: { ...process.env, PI_CODING_AGENT_DIR: dir, OMP_GATEWAY_URL: baseUrl,
        OMP_GATEWAY_TOKEN_FILE: tokenFile, OMP_GATEWAY_COMMAND: omp, OMP_GATEWAY_AGENT_DIR: path.join(dir, "cursor-agent"),
        OMP_PROFILE: "do-not-use", PI_PROFILE: "do-not-use", PI_CONFIG_FILES: "/do-not-use.yml",
        OMP_AUTH_BROKER_URL: "http://do-not-use", OMP_AUTH_BROKER_TOKEN: "do-not-use" },
    });
    children.push(child);
    let buffer = '', stderr = '', seq = 0;
    const events = [], waiters = new Set();
    child.stderr.on('data', chunk => { stderr += chunk; allStderr.push(String(chunk)); });
    child.stdout.on('data', chunk => {
      buffer += chunk;
      let newline;
      while ((newline = buffer.indexOf('\n')) !== -1) {
        const line = buffer.slice(0, newline); buffer = buffer.slice(newline + 1);
        let record;
        try { record = JSON.parse(line); } catch { continue; }
        events.push(record);
        for (const waiter of [...waiters]) if (waiter.predicate(record)) {
          waiters.delete(waiter); clearTimeout(waiter.timer); waiter.resolve(record);
        }
      }
    });
    function wait(predicate) {
      return new Promise((resolve, reject) => {
        const waiter = { predicate, resolve, timer: setTimeout(() => {
          waiters.delete(waiter); reject(new Error(`RPC timeout: ${stderr}`));
        }, 15000) };
        waiters.add(waiter);
      });
    }
    async function command(type, fields = {}) {
      const id = String(++seq);
      const response = wait(record => record.type === 'response' && record.id === id);
      child.stdin.write(JSON.stringify({ id, type, ...fields }) + '\n');
      const record = await response;
      assert.equal(record.success, true, JSON.stringify(record));
      return record;
    }
    async function prompt(message) {
      const from = events.length;
      const done = wait(record => record.type === 'agent_settled');
      await command('prompt', { message }); await done;
      return events.slice(from).filter(record => record.type === 'message_end' && record.message?.role === 'assistant').at(-1).message;
    }
    async function close() {
      for (const waiter of waiters) clearTimeout(waiter.timer);
      if (child.exitCode !== null) return;
      const done = new Promise(resolve => child.once('close', resolve));
      child.stdin.end();
      const timer = setTimeout(() => child.kill('SIGKILL'), 3000);
      await done; clearTimeout(timer);
    }
    return { child, command, prompt, close, events };
  }
  try {
    const runtime = start();
    await runtime.command('set_auto_retry', { enabled: false });
    const before = await runtime.command('get_available_models');
    assert.equal(before.data.models.filter(model => model.provider === 'cursor').length, 0, 'No network or CLI startup work in the factory');
    await runtime.prompt('BOOT');
    requests.length = 0;
    await runtime.command('prompt', { message: '/omp-gateway refresh' });
    const available = await runtime.command('get_available_models');
    const model = available.data.models.find(model => model.provider === 'cursor' && model.id === 'grok-4.7');
    assert.ok(model, JSON.stringify(runtime.events));
    assert.equal(model.thinkingLevelMap.max, null);
    await runtime.command('set_model', { provider: 'cursor', modelId: 'grok-4.7' });
    await runtime.command('set_thinking_level', { level: 'high' });
    const selected = await runtime.command('get_state');
    assert.equal(selected.data.model.provider, 'cursor', JSON.stringify(selected));
    const text = await runtime.prompt('TEXT');
    assert.equal(text.stopReason, 'stop', JSON.stringify(text));
    assert.equal(text.content.find(block => block.type === 'text').text, 'Gateway ✓ Unicode 你好');
    assert.equal(text.provider, 'cursor');
    assert.equal(text.model, 'grok-4.7');
    assert.equal(text.usage.input, 90);
    assert.equal(text.usage.cacheRead, 10);
    assert.equal(text.usage.output, 4);
    assert.ok(text.usage.cost.total > 0);
    assert.equal(requests[0].body.model, 'cursor/grok-4.7');
    assert.equal(requests[0].body.reasoning_effort, 'high');
    assert.ok(requests[0].body.prompt_cache_key);
    await runtime.command('new_session');
    await runtime.prompt('BOOT');
    await runtime.command('set_model', { provider: 'cursor', modelId: 'grok-4.7' });
    await runtime.command('set_thinking_level', { level: 'high' });
    const tool = await runtime.prompt('USE_TOOL');
    assert.equal(tool.stopReason, 'stop', JSON.stringify(tool));
    assert.equal(tool.content.find(block => block.type === 'text').text, 'TOOL_OK');
    assert.ok(requests.at(-1).body.messages.some(message => message.role === 'tool' && JSON.stringify(message.content).includes('LOCAL_FIXTURE_OK')));
    assert.equal(requests.at(-1).body.prompt_cache_key, requests.at(-2).body.prompt_cache_key, 'Keep the tool handoff in the same gateway conversation');
    assert.notEqual(requests[0].body.prompt_cache_key, requests.at(-1).body.prompt_cache_key, 'New sessions must not share Cursor conversations');
    expectedToken = 'rotated-token';
    fs.writeFileSync(tokenFile, expectedToken);
    await runtime.prompt('AFTER_ROTATION');
    assert.equal(requests.at(-1).authorization, 'Bearer rotated-token');
    const empty = await runtime.prompt('EMPTY');
    assert.equal(empty.stopReason, 'stop');
    assert.deepEqual(empty.content, []);
    catalogStatus = 401;
    await runtime.command('prompt', { message: '/omp-gateway refresh' });
    assert.ok(runtime.events.some(record => record.type === 'extension_ui_request' && /HTTP 401/.test(record.message || '')));
    const retained = await runtime.command('get_available_models');
    assert.ok(retained.data.models.some(model => model.provider === 'cursor'), 'Failed refresh must preserve the last catalog');
    assert.ok(!JSON.stringify(runtime.events).includes('DO_NOT_LOG_THIS_SECRET'));
    catalogStatus = 200;
    await runtime.close();
    const restored = start();
    const cached = await restored.command('get_available_models');
    assert.ok(cached.data.models.some(model => model.provider === 'cursor'), 'Pi restores persisted catalog offline');
    rows = [{ id: "xai/grok-4.7", owned_by: "xai" }];
    await restored.command("prompt", { message: "/omp-gateway refresh" });
    assert.ok(restored.events.some(record => record.type === "extension_ui_request" && /non-Cursor/.test(record.message || "")));
    const scoped = await restored.command("get_available_models");
    assert.ok(scoped.data.models.some(model => model.provider === "cursor"), "Reject mixed catalogs without losing cached Cursor models");
    assert.ok(!scoped.data.models.some(model => model.provider === "xai"));
    rows = [];
    await restored.command('prompt', { message: '/omp-gateway refresh' });
    const removed = await restored.command('get_available_models');
    assert.equal(removed.data.models.filter(model => model.provider === 'cursor').length, 0, 'Authoritative empty catalogs remove models');
    await restored.close();
    assert.ok(!allStderr.join('').includes('DO_NOT_LOG_THIS_SECRET'));
  } finally {
    for (const child of children) if (child.exitCode === null) child.kill('SIGKILL');
    server.closeAllConnections();
    await new Promise(resolve => server.close(resolve));
    fs.rmSync(dir, { recursive: true, force: true });
  }
});
