const assert = require('node:assert/strict');
const { spawn } = require('node:child_process');
const fs = require('node:fs');
const http = require('node:http');
const os = require('node:os');
const path = require('node:path');
const { test } = require('node:test');

async function unusedPort() {
  const server = http.createServer();
  await new Promise(resolve => server.listen(0, '127.0.0.1', resolve));
  const port = server.address().port;
  await new Promise(resolve => server.close(resolve));
  return port;
}

// Real OMP services, an empty isolated vault, and no upstream inference requests.
test('OMP services isolate credentials and reject unauthenticated and foreign-model requests', { timeout: 60000 }, async () => {
  const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'omp-cursor-services-'));
  const root = path.join(dir, '.omp-cursor');
  const originalVault = path.join(dir, '.omp', 'agent', 'agent.db');
  fs.mkdirSync(path.dirname(originalVault), { recursive: true, mode: 0o700 });
  fs.writeFileSync(originalVault, 'DO_NOT_OPEN_THE_DEFAULT_VAULT', { mode: 0o600 });
  fs.mkdirSync(path.join(root, 'agent'), { recursive: true, mode: 0o700 });
  const env = {
    HOME: dir,
    PATH: process.env.PATH,
    TMPDIR: dir,
    PI_CONFIG_DIR: '.omp-cursor',
    PI_CODING_AGENT_DIR: path.join(root, 'agent'),
    OMP_PROFILE: '',
    PI_PROFILE: '',
    PI_CONFIG_FILES: '',
  };
  const children = [];
  function start(command, port, environment) {
    const child = spawn(process.env.OMP_GATEWAY_COMMAND || 'omp', [command, 'serve', `--bind=127.0.0.1:${port}`], {
      env: environment, stdio: ['ignore', 'ignore', 'pipe'],
    });
    children.push(child);
    child.stderr.resume();
    child.on('error', () => {});
    return child;
  }
  async function ready(url, child) {
    for (let attempt = 0; attempt < 150; attempt++) {
      if (!child.pid || child.exitCode !== null) throw new Error('OMP service exited before becoming ready.');
      try {
        const response = await fetch(url, { signal: AbortSignal.timeout(1000) });
        if (response.ok) return;
      } catch {}
      await new Promise(resolve => setTimeout(resolve, 100));
    }
    throw new Error('OMP service startup timed out.');
  }
  async function stop(child) {
    if (!child.pid || child.exitCode !== null) return;
    const done = new Promise(resolve => child.once('close', resolve));
    child.kill('SIGTERM');
    const timer = setTimeout(() => child.kill('SIGKILL'), 3000);
    await done;
    clearTimeout(timer);
  }
  try {
    const brokerPort = await unusedPort();
    const brokerUrl = `http://127.0.0.1:${brokerPort}`;
    const broker = start('auth-broker', brokerPort, env);
    await ready(`${brokerUrl}/v1/healthz`, broker);
    const brokerTokenFile = path.join(root, 'auth-broker.token');
    assert.equal(fs.statSync(brokerTokenFile).mode & 0o077, 0);
    const brokerToken = fs.readFileSync(brokerTokenFile, 'utf8').trim();
    const unauthenticatedBroker = await fetch(`${brokerUrl}/v1/snapshot`);
    assert.equal(unauthenticatedBroker.status, 401);
    await unauthenticatedBroker.body.cancel();

    const gatewayPort = await unusedPort();
    const gatewayUrl = `http://127.0.0.1:${gatewayPort}`;
    const gateway = start('auth-gateway', gatewayPort, {
      ...env, OMP_AUTH_BROKER_URL: brokerUrl, OMP_AUTH_BROKER_TOKEN: brokerToken,
    });
    await ready(`${gatewayUrl}/healthz`, gateway);
    const gatewayTokenFile = path.join(root, 'auth-gateway.token');
    assert.equal(fs.statSync(gatewayTokenFile).mode & 0o077, 0);
    const gatewayToken = fs.readFileSync(gatewayTokenFile, 'utf8').trim();
    const unauthenticated = await fetch(`${gatewayUrl}/v1/models`);
    assert.equal(unauthenticated.status, 401);
    await unauthenticated.body.cancel();
    const response = await fetch(`${gatewayUrl}/v1/models`, { headers: { Authorization: `Bearer ${gatewayToken}` } });
    assert.equal(response.status, 200);
    const catalog = await response.json();
    assert.deepEqual(catalog.data, [], 'The empty Cursor vault must not import any default-vault credentials.');
    const foreignModel = await fetch(`${gatewayUrl}/v1/chat/completions`, {
      method: 'POST',
      headers: { Authorization: `Bearer ${gatewayToken}`, 'Content-Type': 'application/json' },
      body: JSON.stringify({ model: 'xai/grok-4.7', messages: [{ role: 'user', content: 'Do not run inference.' }] }),
    });
    assert.equal(foreignModel.status, 404, 'Non-Cursor credentials must not provide a route.');
    await foreignModel.body.cancel();
    assert.ok(fs.existsSync(path.join(root, 'agent', 'agent.db')));
    assert.equal(fs.readFileSync(originalVault, 'utf8'), 'DO_NOT_OPEN_THE_DEFAULT_VAULT');
  } finally {
    await Promise.all(children.map(stop));
    fs.rmSync(dir, { recursive: true, force: true });
  }
});
