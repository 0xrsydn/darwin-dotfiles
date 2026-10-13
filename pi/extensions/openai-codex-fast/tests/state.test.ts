import assert from "node:assert/strict";
import test from "node:test";
import { isRecord } from "../../openai-server-compaction/config.ts";
import { applyRemoteHistoryPayloadPatch } from "../../openai-server-compaction/openai.ts";
import { FAST_STATE_ENTRY, isCodexModel, parseFastCommand, patchFastPayload, restoreFastMode } from "../state.ts";

const model = { provider: "openai-codex", api: "openai-codex-responses", id: "gpt-5.5" };
const payload = {
  model: model.id,
  input: [{ role: "user", content: "Hello" }],
  reasoning: { effort: "high", summary: "auto" },
  store: false,
  stream: true,
};
const entry = (enabled: unknown) => ({ type: "custom", customType: FAST_STATE_ENTRY, data: { enabled } });

test("parses toggle, explicit settings, and status without accepting extra arguments", () => {
  assert.equal(parseFastCommand(""), "toggle");
  assert.equal(parseFastCommand(" ON "), "on");
  assert.equal(parseFastCommand("off"), "off");
  assert.equal(parseFastCommand("status"), "status");
  for (const args of ["on extra", "toggle", "true"]) assert.equal(parseFastCommand(args), undefined);
});

test("targets only the exact Codex provider and API", () => {
  assert.equal(isCodexModel(model), true);
  assert.equal(isCodexModel(undefined), false);
  assert.equal(isCodexModel({ ...model, provider: "openai" }), false);
  assert.equal(isCodexModel({ ...model, api: "openai-responses" }), false);
  assert.equal(isCodexModel({ ...model, provider: "proxy" }), false);
});

test("adds priority without changing model, reasoning, input, or the original payload", () => {
  const frozen = Object.freeze({ ...payload, service_tier: "flex" });
  assert.deepEqual(patchFastPayload({ enabled: true, model, payload: frozen }), {
    ...frozen, service_tier: "priority",
  });
  assert.equal(frozen.service_tier, "flex");
});

test("leaves disabled, unrelated, malformed, and mismatched requests unchanged", () => {
  assert.equal(patchFastPayload({ enabled: false, model, payload }), undefined);
  assert.equal(patchFastPayload({ enabled: true, model: undefined, payload }), undefined);
  assert.equal(patchFastPayload({ enabled: true, model: { ...model, provider: "openai" }, payload }), undefined);
  assert.equal(patchFastPayload({ enabled: true, model: { ...model, api: "openai-responses" }, payload }), undefined);
  for (const value of [null, 1, "payload", [], {}, { ...payload, model: "other" }, { model: model.id }, { ...payload, input: {} }]) {
    assert.equal(patchFastPayload({ enabled: true, model, payload: value }), undefined);
  }
});

test("restores the last valid state on the active branch and defaults new sessions to off", () => {
  assert.equal(restoreFastMode([]), false);
  assert.equal(restoreFastMode([entry(true)]), true);
  assert.equal(restoreFastMode([entry(true), entry(false)]), false);
  assert.equal(restoreFastMode([entry(false), entry(true)]), true);
  assert.equal(restoreFastMode([entry(true), { type: "compaction" }]), true);
  assert.equal(restoreFastMode([entry(true)].slice(0, 0)), false);
});

test("ignores invalid snapshots and entries owned by other extensions", () => {
  const invalid = [null, 1, {}, entry("true"), entry(null), { ...entry(false), customType: "other" }, { ...entry(false), type: "custom_message" }];
  assert.equal(restoreFastMode(invalid), false);
  assert.equal(restoreFastMode([entry(true), ...invalid]), true);
});

test("composes with the existing compaction payload patch in either order", () => {
  const explicitHistory = [{ type: "compaction", encrypted_content: "fixture" }];
  const request = { ...payload, previous_response_id: "old" };
  const compacted = applyRemoteHistoryPayloadPatch({ payload: request, explicitHistory });
  const expected = { ...payload, input: explicitHistory, service_tier: "priority" };
  assert.deepEqual(patchFastPayload({ enabled: true, model, payload: compacted }), expected);
  const fast = patchFastPayload({ enabled: true, model, payload: request });
  assert.ok(isRecord(fast));
  assert.deepEqual(applyRemoteHistoryPayloadPatch({ payload: fast, explicitHistory }), expected);
});
