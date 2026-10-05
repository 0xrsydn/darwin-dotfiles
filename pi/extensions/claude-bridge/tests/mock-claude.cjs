// Offline CLI fixture. The regression runner installs it as `claude` in a temporary PATH.
const fs = require('node:fs');
const args = process.argv.slice(2);
const flag = (name) => args[args.indexOf(name) + 1];
const model = flag('--model');
const mcp = args.includes('--mcp-config') ? JSON.parse(fs.readFileSync(flag('--mcp-config'), 'utf8')).mcpServers.pi.url : null;
let count = 0, memory = '', buffer = '';
const emit = (message) => process.stdout.write(JSON.stringify(message) + '\n');
const event = (event) => emit({ type: 'stream_event', event });
const delay = (ms) => new Promise((resolve) => setTimeout(resolve, ms));
async function answer(text) {
  const id = `text-${++count}`;
  event({ type: 'message_start', message: { id, usage: { input_tokens: 10, output_tokens: 0 } } });
  event({ type: 'content_block_start', index: 0, content_block: { type: 'text' } });
  event({ type: 'content_block_delta', index: 0, delta: { type: 'text_delta', text } });
  event({ type: 'content_block_stop', index: 0 });
  event({ type: 'message_delta', delta: { stop_reason: 'end_turn' }, usage: { output_tokens: 5 } });
  event({ type: 'message_stop' });
  emit({ type: 'assistant', message: { id, content: [{ type: 'text', text }], usage: { input_tokens: 10, output_tokens: 5 } } });
  // Expose the original bug: a new Pi prompt must not start before this result.
  await delay(150);
  emit({ type: 'result', subtype: 'success', result: text, usage: { input_tokens: 100, output_tokens: 50 } });
}
async function tool(name, input, nonStreaming = false, inlineInput = false) {
  const id = `tool-${++count}`;
  const block = { type: 'tool_use', id, name: `mcp__pi__${name}`, input };
  const message = { id: `assistant-${id}`, content: [block], usage: { input_tokens: 10, output_tokens: 5 } };
  if (nonStreaming) emit({ type: 'assistant', message });
  else {
    event({ type: 'message_start', message });
    event({ type: 'content_block_start', index: 0, content_block: block });
    if (!inlineInput) event({ type: 'content_block_delta', index: 0, delta: { type: 'input_json_delta', partial_json: JSON.stringify(input) } });
    event({ type: 'content_block_stop', index: 0 });
    event({ type: 'message_delta', delta: { stop_reason: 'tool_use' }, usage: { output_tokens: 5 } });
    event({ type: 'message_stop' });
    // The full assistant record can arrive after Pi opens its tool-result stream.
    await delay(80);
    emit({ type: 'assistant', message });
  }
  const response = await fetch(mcp, { method: 'POST', body: JSON.stringify({ jsonrpc: '2.0', id, method: 'tools/call', params: { name, arguments: input, _meta: { 'claudecode/toolUseId': id } } }) });
  const result = (await response.json()).result;
  await answer(result?.isError ? 'TOOL_ERROR_HANDLED' : 'TOOL_OK');
}
async function handle(record) {
  const content = record.message.content;
  const text = content.filter((block) => block.type === 'text').map((block) => block.text).join('\n');
  const prompt = content.at(-1)?.text || '';
  if (text.includes('MEMORY_73921')) memory = 'MEMORY_73921';
  fs.appendFileSync(process.env.BRIDGE_TEST_LOG, JSON.stringify({ pid: process.pid, model, effort: args.includes('--effort') ? flag('--effort') : null, text, apiKey: Boolean(process.env.ANTHROPIC_API_KEY) }) + '\n');
  if (prompt === 'MOCK_ABORT') {
    event({ type: 'message_start', message: { id: 'abort', usage: {} } });
    event({ type: 'content_block_start', index: 0, content_block: { type: 'text' } });
    event({ type: 'content_block_delta', index: 0, delta: { type: 'text_delta', text: 'ABORT_STARTED' } });
    return;
  }
  if (prompt === 'MOCK_EXIT') return process.exit(7);
  if (prompt === 'MOCK_INLINE_TOOL') return tool('read', { path: process.env.BRIDGE_TEST_FILE }, false, true);
  if (prompt === 'MOCK_TOOL') return tool('read', { path: process.env.BRIDGE_TEST_FILE });
  if (prompt === 'MOCK_FALLBACK_TOOL') return tool('read', { path: process.env.BRIDGE_TEST_FILE }, true);
  if (prompt === 'MOCK_TOOL_ERROR') return tool('read', { path: process.env.BRIDGE_TEST_FILE + '.missing' });
  if (prompt === 'MOCK_SLOW_TOOL') return tool('bridge_wait', {});
  if (prompt === 'MOCK_MEMORY') return answer(memory || 'UNKNOWN');
  if (prompt === 'MOCK_MODEL') return answer(model);
  if (prompt === 'MOCK_CLI_ERROR') {
    emit({ type: 'result', is_error: true, errors: ['MOCK_PROVIDER_FAILURE'] });
    return;
  }
  return answer(prompt);
}
let queue = Promise.resolve();
process.stdin.on('data', (chunk) => {
  buffer += chunk;
  let newline;
  while ((newline = buffer.indexOf('\n')) !== -1) {
    const line = buffer.slice(0, newline); buffer = buffer.slice(newline + 1);
    if (line) queue = queue.then(() => handle(JSON.parse(line))).catch((error) => { console.error(error); process.exit(1); });
  }
});
process.stdin.on('end', () => { queue.finally(() => process.exit(0)); });
// Exercise old-process cleanup after the replacement request has already started.
process.on('SIGTERM', () => setTimeout(() => process.exit(0), 250));
