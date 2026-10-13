import assert from "node:assert/strict";
import { test } from "node:test";
import { assertCursorOnlyCatalog, discoverCursorModels, gatewayCursorRows, gatewayPayload, loopbackBaseUrl } from "../catalog.ts";

function catalogs() {
  return {
    gateway: { data: [{ id: "cursor/grok-4.7", owned_by: "cursor", display_name: "Grok 4.7", context_length: 256000,
      max_output_tokens: 64000, input_modalities: ["text", "image"] }] },
    local: { models: [{ provider: "cursor", kind: "chat", id: "grok-4.7", name: "Grok 4.7", input: ["text", "image"],
      reasoning: true, thinking: ["low", "medium", "high", "xhigh"], contextWindow: 500000, maxTokens: 64000,
      cost: { input: 2, output: 6, cacheRead: 0.5, cacheWrite: 0 } }] },
  };
}

test("joins routable models with OMP pricing, capabilities, and thinking levels", () => {
  const { gateway, local } = catalogs();
  const models = discoverCursorModels(gateway, local, "http://127.0.0.1:4000/v1");
  assert.equal(models.length, 1);
  const [model] = models;
  assert.equal(model.provider, "cursor");
  assert.equal(model.id, "grok-4.7");
  assert.equal(model.contextWindow, 256000, "Use the conservative intersection, not a guessed 500k limit");
  assert.deepEqual(model.cost, { input: 2, output: 6, cacheRead: 0.5, cacheWrite: 0 });
  assert.equal(model.thinkingLevelMap?.max, null);
  assert.equal(model.thinkingLevelMap?.xhigh, "xhigh");
  assert.deepEqual(model.input, ["text", "image"]);
});

test("excludes other providers, unsupported tools, non-chat models, and unsafe ids", () => {
  const { gateway } = catalogs();
  const valid = gateway.data[0];
  const payload = { data: [valid, { ...valid, owned_by: "xai" }, { ...valid, supports_tools: false },
    { ...valid, kind: "image" }, { ...valid, id: "cursor/../../key" }, null] };
  assert.equal(gatewayCursorRows(payload).length, 1);
  assert.throws(() => gatewayCursorRows({ error: "not a catalog" }), /invalid model catalog/);
});

test("rejects a shared-provider gateway before model discovery", () => {
  assertCursorOnlyCatalog(catalogs().gateway);
  assertCursorOnlyCatalog({ data: [] });
  for (const row of [{ id: "xai/grok-4.7", owned_by: "xai" },
    { id: "xai/grok-4.7", owned_by: "cursor" }, null]) {
    assert.throws(() => assertCursorOnlyCatalog({ data: [row] }), /non-Cursor/);
  }
});

test("never substitutes zero prices or guessed capabilities for malformed metadata", () => {
  const { gateway, local } = catalogs();
  local.models[0].cost.input = Number.NaN;
  assert.throws(() => discoverCursorModels(gateway, local, "http://localhost:4000/v1"), /invalid pricing/);
  const fresh = catalogs();
  fresh.local.models[0].thinking = [];
  assert.throws(() => discoverCursorModels(fresh.gateway, fresh.local, "http://localhost:4000/v1"), /thinking-level/);
  assert.throws(() => discoverCursorModels(fresh.gateway, { models: [] }, "http://localhost:4000/v1"), /do not match/);
});

test("accepts an authoritative empty catalog and deduplicates model ids", () => {
  const { gateway, local } = catalogs();
  gateway.data.push(gateway.data[0]);
  assert.equal(discoverCursorModels(gateway, local, "http://localhost:4000/v1").length, 1);
  assert.deepEqual(discoverCursorModels({ data: [] }, local, "http://localhost:4000/v1"), []);
});

test("qualifies wire ids and keeps session identity and request fields", () => {
  assert.deepEqual(gatewayPayload({ model: "grok-4.7", messages: [], temperature: 0.5 }, "grok-4.7", "session-one"),
    { model: "cursor/grok-4.7", messages: [], temperature: 0.5, prompt_cache_key: "session-one" });
  assert.throws(() => gatewayPayload(null, "grok-4.7"), /Invalid/);
  assert.throws(() => gatewayPayload({}, "../bad"), /Invalid/);
});

test("rejects remote endpoints, embedded credentials, and query strings", () => {
  assert.equal(loopbackBaseUrl("http://127.0.0.1:4000/v1/"), "http://127.0.0.1:4000/v1");
  assert.equal(loopbackBaseUrl("http://[::1]:4000/v1"), "http://[::1]:4000/v1");
  for (const url of ["https://remote.example/v1", "http://token@localhost:4000/v1", "http://localhost/v1?token=x", "http://localhost/"]) {
    assert.throws(() => loopbackBaseUrl(url), /loopback/);
  }
});
