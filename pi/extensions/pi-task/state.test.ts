import assert from "node:assert/strict";
import test from "node:test";
import { TaskStore, restoreTasks, type Task } from "./state.ts";

const active: Task[] = [{ text: "Build feature", status: "in_progress" }];
const done: Task[] = [{ text: "Build feature", status: "completed" }];
const result = (tasks: Task[], isError = false) => ({
  type: "message", message: { role: "toolResult", toolName: "task", isError, details: { tasks } },
});

test("restores the last valid snapshot on the active branch, including a clear", () => {
  assert.deepEqual(restoreTasks([result(active), result(done, true), result(done)]), done);
  assert.deepEqual(restoreTasks([result(active), result([])]), []);
  assert.deepEqual(restoreTasks([result(active), {
    type: "message", message: { role: "toolResult", toolName: "task", details: { tasks: [{ text: "bad", status: "invalid" }] } },
  }]), active);
});

test("serializes concurrent updates and returns independent snapshots", async () => {
  const store = new TaskStore();
  const first = store.call(active);
  const second = store.call(done);
  assert.deepEqual(await first, { tasks: active, wasComplete: false });
  assert.deepEqual(await second, { tasks: done, wasComplete: false });
  assert.deepEqual(store.read(), done);
  const snapshot = store.read();
  snapshot[0].text = "changed";
  assert.deepEqual(store.read(), done);
});

test("rejects invalid and cancelled calls without changing state", async () => {
  const store = new TaskStore();
  await store.call(active);
  await assert.rejects(store.call([{ text: "  ", status: "pending" }]), /empty/);
  const controller = new AbortController();
  controller.abort();
  await assert.rejects(store.call(done, controller.signal), /cancelled/);
  assert.deepEqual(store.read(), active);
});

test("rejects queued calls after a branch change", async () => {
  const store = new TaskStore();
  const queued = store.call(done);
  store.restore([result(active)]);
  await assert.rejects(queued, /session changed/);
  assert.deepEqual(store.read(), active);
});
