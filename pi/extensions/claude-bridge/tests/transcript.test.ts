import assert from "node:assert/strict";
import { test } from "node:test";
import { extendsTranscript, restoredContent, transcriptKeys, type TranscriptMessage } from "../transcript.ts";

const user = { role: "user", content: "Remember MEMORY_73921" };
const assistant = { role: "assistant", content: [{ type: "text", text: "ACK", index: 0 }], timestamp: 1 };

test("fingerprints ignore runtime fields but detect branch and content changes", () => {
  const previous = transcriptKeys([user, assistant]);
  const current = transcriptKeys([
    { role: "system", content: "Changed prompt" }, user,
    { ...assistant, timestamp: 2, usage: { input: 10 }, content: [{ type: "text", text: "ACK" }] },
    { role: "user", content: "Next" },
  ]);
  assert.ok(extendsTranscript(previous, current));
  assert.ok(!extendsTranscript(previous, transcriptKeys([user])));
  assert.ok(!extendsTranscript(previous, transcriptKeys([user, { ...assistant, content: "Different" }])));
});

test("tool argument key order does not force a restart", () => {
  const message = (args: unknown): TranscriptMessage => ({ role: "assistant", content: [{ type: "toolCall", id: "id", name: "read", arguments: args }] });
  assert.deepEqual(transcriptKeys([message({ a: 1, b: 2 })]), transcriptKeys([message({ b: 2, a: 1 })]));
});

test("restoration includes prior messages, tool results, and current input without native calls", () => {
  const blocks = restoredContent([
    { role: "system", content: "SYSTEM_PROMPT_NOT_REPLAYED" }, user, assistant,
    { role: "toolResult", toolCallId: "old-id", toolName: "read", content: "ERROR_73921", isError: true },
    { role: "user", content: "Current request" },
  ]);
  const text = blocks.filter((block) => block.type === "text").map((block) => block.text).join("\n");
  assert.match(text, /MEMORY_73921/);
  assert.match(text, /ERROR_73921/);
  assert.match(text, /"isError":true/);
  assert.ok(!text.includes("SYSTEM_PROMPT_NOT_REPLAYED"));
  assert.equal(blocks.at(-1)?.type, "text");
  assert.equal((blocks.at(-1) as { text: string }).text, "Current request");
  assert.ok(blocks.every((block) => block.type === "text" || block.type === "image"));
});

test("historical images stay image blocks; thinking signatures are not replayed", () => {
  const blocks = restoredContent([
    { role: "user", content: [{ type: "image", data: "aW1hZ2U=", mimeType: "image/png" }] },
    { role: "assistant", content: [{ type: "thinking", thinking: "private", thinkingSignature: "secret-signature" }] },
    { role: "user", content: "Next" },
  ]);
  assert.equal(blocks.filter((block) => block.type === "image").length, 1);
  const text = JSON.stringify(blocks);
  assert.ok(!text.includes("secret-signature"));
  assert.ok(!text.includes("private"));
});

test("tool-result tail gets a continuation request instead of replaying tool calls", () => {
  const blocks = restoredContent([{ role: "toolResult", toolCallId: "id", content: "DONE" }]);
  assert.match((blocks.at(-1) as { text: string }).text, /Continue the latest user request/);
});
