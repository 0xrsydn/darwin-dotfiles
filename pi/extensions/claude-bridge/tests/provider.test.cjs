const assert = require('node:assert/strict');
const { spawn } = require('node:child_process');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const { test } = require('node:test');

// Uses the installed Pi loader and runtime. No npm installation or API request is needed.
test('provider turn boundaries, restarts, fallback tools, errors, and steering', { timeout: 90000 }, async () => {
  const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'pi-bridge-regression-'));
  const cli = path.join(dir, 'claude');
  const log = path.join(dir, 'cli.jsonl');
  const fixture = path.join(dir, 'fixture.txt');
  const helper = path.join(dir, 'helper.ts');
  fs.writeFileSync(cli, `#!/bin/sh\nexec ${JSON.stringify(process.execPath)} ${JSON.stringify(path.join(__dirname, 'mock-claude.cjs'))} "$@"\n`, { mode: 0o700 });
  fs.writeFileSync(fixture, 'FIXTURE_CONTENT');
  fs.writeFileSync(path.join(dir, 'settings.json'), JSON.stringify({ compaction: { enabled: true, keepRecentTokens: 100, reserveTokens: 1000 } }));
  fs.writeFileSync(helper, `export default function(pi) {
    let suffix = '';
    pi.on('before_agent_start', event => suffix ? { systemPrompt: event.systemPrompt + suffix } : undefined);
    pi.registerCommand('bridge_prompt', { description: 'Change test prompt', handler: async () => { suffix = '\\nTEST_PROMPT_CHANGED'; } });
    pi.registerCommand('bridge_tools', { description: 'Change test tools', handler: async () => { pi.setActiveTools(['read']); } });
    pi.registerTool({ name: 'bridge_wait', label: 'Wait', description: 'Test wait', parameters: { type: 'object', properties: {} },
      execute: async () => { await new Promise(r => setTimeout(r, 400)); return { content: [{ type: 'text', text: 'WAIT_OK' }], details: undefined }; } });
  }`);
  const child = spawn('pi', [
    '--offline', '--no-extensions', '--no-mcp', '--no-skills', '--no-prompt-templates', '--no-context-files', '--no-session',
    '-e', path.resolve(__dirname, '../index.ts'), '-e', helper,
    '--model', 'claude-bridge/claude-haiku-5-5', '--thinking', 'off', '--tools', 'read,bridge_wait', '--mode', 'rpc',
  ], { env: { ...process.env, PATH: `${dir}:${process.env.PATH}`, ANTHROPIC_API_KEY: 'must-not-reach-child', BRIDGE_TEST_LOG: log, BRIDGE_TEST_FILE: fixture, PI_CODING_AGENT_DIR: dir } });
  let buffer = '', stderr = '', seq = 0;
  const events = [], waiters = new Set();
  child.stderr.on('data', (chunk) => { stderr += chunk; });
  child.stdout.on('data', (chunk) => {
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
        waiters.delete(waiter); reject(new Error(`RPC timeout. stderr: ${stderr}`));
      }, 10000) };
      waiters.add(waiter);
    });
  }
  async function command(type, fields = {}) {
    const id = String(++seq);
    const response = wait((record) => record.type === 'response' && record.id === id);
    child.stdin.write(JSON.stringify({ id, type, ...fields }) + '\n');
    const record = await response;
    assert.equal(record.success, true, JSON.stringify(record));
    return record;
  }
  function answersSince(start) {
    return events.slice(start).filter((record) => record.type === 'message_end' && record.message?.role === 'assistant');
  }
  async function prompt(message) {
    const start = events.length;
    const settled = wait((record) => record.type === 'agent_settled');
    await command('prompt', { message }); await settled;
    const answers = answersSince(start);
    const last = answers.at(-1)?.message;
    return { start, answers, last, text: last?.content.filter((block) => block.type === 'text').map((block) => block.text).join('') };
  }
  const cliRecords = () => fs.readFileSync(log, 'utf8').trim().split('\n').map(JSON.parse);
  try {
    await command('set_auto_retry', { enabled: false });
    for (let i = 0; i < 5; i++) {
      const result = await prompt(`RAPID_${i}`);
      assert.equal(result.text, `RAPID_${i}`);
      assert.equal(result.answers.length, 1);
      assert.equal(result.last.usage.input, 10, 'Do not overwrite message usage with aggregate CLI result usage');
    }
    assert.equal(new Set(cliRecords().map((record) => record.pid)).size, 1, 'Reuse the process on normal turns');
    assert.ok(cliRecords().every((record) => record.apiKey === false));
    assert.equal((await prompt('Remember MEMORY_73921')).last.stopReason, 'stop');
    assert.equal((await prompt('MOCK_MEMORY')).text, 'MEMORY_73921');
    for (const name of ['MOCK_TOOL', 'MOCK_INLINE_TOOL', 'MOCK_FALLBACK_TOOL', 'MOCK_TOOL_ERROR']) {
      const result = await prompt(name);
      assert.equal(result.text, name === 'MOCK_TOOL_ERROR' ? 'TOOL_ERROR_HANDLED' : 'TOOL_OK');
      const tools = events.slice(result.start).filter((record) => record.type === 'tool_execution_end');
      assert.equal(tools.length, 1, 'Do not execute the late full assistant record twice');
      assert.equal(tools[0].isError, name === 'MOCK_TOOL_ERROR');
    }
    const error = await prompt('MOCK_CLI_ERROR');
    assert.equal(error.last.stopReason, 'error');
    assert.match(error.last.errorMessage, /MOCK_PROVIDER_FAILURE/);
    assert.equal((await prompt('AFTER_ERROR_OK')).text, 'AFTER_ERROR_OK');
    const exited = await prompt('MOCK_EXIT');
    assert.equal(exited.last.stopReason, 'error');
    assert.match(exited.last.errorMessage, /exited with code 7/);
    assert.equal((await prompt('MOCK_MEMORY')).text, 'MEMORY_73921', 'Restore after an unexpected CLI exit');
    await command('set_thinking_level', { level: 'high' });
    assert.equal((await prompt('MOCK_MEMORY')).text, 'MEMORY_73921');
    assert.equal(cliRecords().at(-1).effort, 'high');
    await command('set_thinking_level', { level: 'off' });
    const started = wait((record) => record.type === 'message_update' && record.assistantMessageEvent?.type === 'text_delta');
    await command('prompt', { message: 'MOCK_ABORT' }); await started;
    await command('abort');
    assert.equal((await prompt('MOCK_MEMORY')).text, 'MEMORY_73921', 'Restore memory after abort');
    assert.match(cliRecords().at(-1).text, /restore the active Pi conversation/);
    assert.equal((await prompt('MOCK_TOOL')).text, 'TOOL_OK', 'Old-process cleanup must not clear new pending calls');
    const toolStart = wait((record) => record.type === 'tool_execution_start' && record.toolName === 'bridge_wait');
    const settled = wait((record) => record.type === 'agent_settled');
    const start = events.length;
    await command('prompt', { message: 'MOCK_SLOW_TOOL' }); await toolStart;
    await command('steer', { message: 'STEER_OK' }); await settled;
    const steered = answersSince(start).at(-1).message.content.filter((block) => block.type === 'text').map((block) => block.text).join('');
    assert.equal(steered, 'STEER_OK');
    const beforePromptChange = cliRecords().at(-1).pid;
    await command('prompt', { message: '/bridge_prompt' });
    assert.equal((await prompt('MOCK_MEMORY')).text, 'MEMORY_73921');
    assert.notEqual(cliRecords().at(-1).pid, beforePromptChange, 'Changed prompt restarts the CLI');
    const beforeToolChange = cliRecords().at(-1).pid;
    await command('prompt', { message: '/bridge_tools' });
    assert.equal((await prompt('MOCK_MEMORY')).text, 'MEMORY_73921');
    assert.notEqual(cliRecords().at(-1).pid, beforeToolChange, 'Changed tools restart the CLI');
    await command('set_model', { provider: 'claude-bridge', modelId: 'claude-haiku-4-5' });
    assert.equal((await prompt('MOCK_MODEL')).text, 'claude-haiku-4-5');
    await prompt('Compaction context: ' + 'Previous test data. '.repeat(500));
    await command('compact', { customInstructions: 'Preserve MEMORY_73921.' });
    assert.equal((await prompt('MOCK_MEMORY')).text, 'MEMORY_73921', 'Restore the compacted active transcript');
    assert.match(cliRecords().at(-1).text, /restore the active Pi conversation/);
    const forks = await command('get_fork_messages');
    await command('fork', { entryId: forks.data.messages.find((message) => message.text === 'RAPID_0').entryId });
    assert.equal((await prompt('MOCK_MEMORY')).text, 'UNKNOWN', 'An earlier branch must not retain abandoned history');
    await command('new_session');
    assert.equal((await prompt('MOCK_MEMORY')).text, 'UNKNOWN');
    assert.ok(!cliRecords().at(-1).text.includes('MEMORY_73921'));
  } finally {
    for (const waiter of waiters) clearTimeout(waiter.timer);
    const closed = new Promise((resolve) => child.once('close', resolve));
    child.stdin.end();
    const timer = setTimeout(() => child.kill('SIGKILL'), 3000);
    await closed; clearTimeout(timer);
    fs.rmSync(dir, { recursive: true, force: true });
  }
});
