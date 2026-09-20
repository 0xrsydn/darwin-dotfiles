import type {
  ExtensionAPI,
  ExtensionContext,
  Theme,
} from "@earendil-works/pi-coding-agent";
import { StringEnum } from "@earendil-works/pi-ai";
import { Text } from "@earendil-works/pi-tui";
import { Type } from "typebox";
import { TaskStore, type Task, type TaskDetails } from "./state.js";

const TaskParams = Type.Object({
  tasks: Type.Optional(
    Type.Array(
      Type.Object({
        text: Type.String({ description: "Short, outcome-oriented task description" }),
        status: StringEnum(["pending", "in_progress", "completed"] as const),
      }),
      {
        description:
          "Complete ordered task list. Submit the full list to add, update, reorder, or remove tasks. Omit to read it.",
      },
    ),
  ),
});

function formatTask(task: Task): string {
  const marker = {
    pending: "○",
    in_progress: "●",
    completed: "✓",
  }[task.status];

  return `${marker} ${task.text}`;
}

function formatThemedTask(task: Task, theme: Theme): string {
  const marker = {
    pending: theme.fg("dim", "○"),
    in_progress: theme.fg("accent", "●"),
    completed: theme.fg("success", "✓"),
  }[task.status];
  const text = task.status === "pending" ? theme.fg("muted", task.text) : theme.fg("text", task.text);

  return `${marker} ${text}`;
}

export default function (pi: ExtensionAPI) {
  const store = new TaskStore();
  let turnsSinceTask = 0;
  let reminderDue = false;

  const refreshTaskUI = (ctx: ExtensionContext) => {
    if (!ctx.hasUI || ctx.mode !== "tui") return;

    const tasks = store.read();
    const completed = tasks.filter((task) => task.status === "completed").length;
    const remaining = tasks.filter((task) => task.status !== "completed");

    if (remaining.length === 0) {
      ctx.ui.setWidget("pi-task", undefined);
      ctx.ui.setStatus("pi-task", undefined);
      return;
    }

    ctx.ui.setStatus(
      "pi-task",
      ctx.ui.theme.fg("accent", `● Tasks ${completed}/${tasks.length}`),
    );
    ctx.ui.setWidget("pi-task", (_tui, theme) => {
      const visible = remaining.slice(0, 7);
      const lines = [
        `${theme.fg("accent", theme.bold("Tasks"))} ${theme.fg("muted", `${completed}/${tasks.length}`)}`,
        ...visible.map((task) => formatThemedTask(task, theme)),
      ];
      const hidden = remaining.length - visible.length;
      if (hidden > 0) lines.push(theme.fg("dim", `… ${hidden} more`));

      return new Text(lines.join("\n"), 0, 0);
    });
  };

  const reconstructState = (ctx: ExtensionContext) => {
    store.restore(ctx.sessionManager.getBranch());
    turnsSinceTask = 0;
    reminderDue = store.read().some((task) => task.status !== "completed");
    refreshTaskUI(ctx);
  };

  pi.on("session_start", async (_event, ctx) => reconstructState(ctx));
  pi.on("session_tree", async (_event, ctx) => reconstructState(ctx));

  pi.on("turn_start", async () => { turnsSinceTask++; });
  pi.on("session_compact", async () => {
    if (store.read().some((task) => task.status !== "completed")) reminderDue = true;
  });
  pi.on("context", async (event) => {
    const open = store.read().filter((task) => task.status !== "completed");
    if (open.length === 0 || (!reminderDue && turnsSinceTask < 2)) return;
    reminderDue = false;
    turnsSinceTask = 0;
    const shown = open.slice(0, 7).map((task) => `${task.status}: ${task.text.replace(/\s+/g, " ").slice(0, 120)}`);
    const more = open.length > shown.length ? `; ${open.length - shown.length} more open` : "";
    return {
      messages: [
        ...event.messages,
        {
          role: "user" as const,
          content: [{ type: "text" as const, text: `Task status reminder (${open.length} open): ${shown.join("; ")}${more}. Check actual work, then call task to update the complete list before reporting completion. Do not mark unfinished work complete.` }],
          timestamp: Date.now(),
        },
      ],
    };
  });
  pi.on("agent_settled", async (_event, ctx) => {
    const tasks = store.read();
    const open = tasks.filter((task) => task.status !== "completed").length;
    if (open > 0 && ctx.mode === "tui") {
      ctx.ui.notify(`${open} task(s) still open. If work is complete, update the task list.`, "warning");
    }
  });

  pi.registerTool({
    name: "task",
    label: "Task",
    description:
      "Read or replace the complete ordered task list. Submit the full list to add, update, reorder, remove, or clear tasks. At most one task may be in_progress.",
    promptSnippet: "Maintain an ordered task list for multi-step work",
    promptGuidelines: [
      "Use task for work with multiple meaningful steps; skip it for simple one-step requests.",
      "Keep task items short and outcome-oriented, and submit the complete ordered list whenever it changes.",
      "Keep exactly one task in_progress while actively working. Mark each task completed after verifying it.",
      "Before reporting work complete, call task with the full updated list; do not leave finished work in_progress.",
    ],
    parameters: TaskParams,

    async execute(_toolCallId, params, signal, _onUpdate, ctx) {
      const { tasks, wasComplete } = await store.call(params.tasks, signal);
      turnsSinceTask = 0;
      reminderDue = false;
      const isComplete = tasks.length > 0 && tasks.every((task) => task.status === "completed");
      // Rendering must not turn a committed task result into an error result.
      try {
        refreshTaskUI(ctx);
        if (ctx.hasUI && isComplete && !wasComplete) {
          ctx.ui.notify(`✓ All ${tasks.length} tasks completed`, "info");
        }
      } catch { /* Keep the saved result even if the UI is unavailable. */ }

      return {
        content: [
          {
            type: "text",
            text: tasks.length > 0 ? tasks.map(formatTask).join("\n") : "No tasks",
          },
        ],
        details: { tasks } satisfies TaskDetails,
      };
    },
  });

  pi.registerCommand("tasks", {
    description: "Refresh and show the current task list",
    handler: async (_args, ctx) => {
      refreshTaskUI(ctx);
      if (ctx.hasUI) {
        const tasks = store.read();
        const remaining = tasks.filter((task) => task.status !== "completed").length;
        const message =
          tasks.length === 0
            ? "No tasks"
            : remaining === 0
              ? `✓ All ${tasks.length} tasks completed; task UI is hidden`
              : `${remaining} task(s) remaining; task UI refreshed`;
        ctx.ui.notify(message, "info");
      }
    },
  });
}
