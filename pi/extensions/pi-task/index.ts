import type {
  ExtensionAPI,
  ExtensionContext,
  Theme,
} from "@earendil-works/pi-coding-agent";
import { StringEnum } from "@earendil-works/pi-ai";
import { Text } from "@earendil-works/pi-tui";
import { Type } from "typebox";

type TaskStatus = "pending" | "in_progress" | "completed";

interface Task {
  text: string;
  status: TaskStatus;
}

interface TaskDetails {
  tasks: Task[];
}

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

function cloneTasks(tasks: Task[]): Task[] {
  return tasks.map((task) => ({ ...task }));
}

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
  let tasks: Task[] = [];

  const refreshTaskUI = (ctx: ExtensionContext) => {
    if (!ctx.hasUI) return;

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
    tasks = [];

    for (const entry of ctx.sessionManager.getBranch()) {
      if (entry.type !== "message") continue;
      const message = entry.message;
      if (message.role !== "toolResult" || message.toolName !== "task") continue;

      const saved = message.details as TaskDetails | undefined;
      if (saved && Array.isArray(saved.tasks)) tasks = cloneTasks(saved.tasks);
    }

    refreshTaskUI(ctx);
  };

  pi.on("session_start", async (_event, ctx) => reconstructState(ctx));
  pi.on("session_tree", async (_event, ctx) => reconstructState(ctx));

  pi.registerTool({
    name: "task",
    label: "Task",
    description:
      "Read or replace the complete ordered task list. Submit the full list to add, update, reorder, remove, or clear tasks. At most one task may be in_progress.",
    promptSnippet: "Maintain an ordered task list for multi-step work",
    promptGuidelines: [
      "Use task for work with multiple meaningful steps; skip it for simple one-step requests.",
      "Keep task items short and outcome-oriented, and submit the complete ordered list whenever it changes.",
      "Keep exactly one task in_progress while actively working, and complete all tasks before finishing.",
    ],
    parameters: TaskParams,

    async execute(_toolCallId, params, _signal, _onUpdate, ctx) {
      const wasComplete = tasks.length > 0 && tasks.every((task) => task.status === "completed");

      if (params.tasks !== undefined) {
        const normalized = params.tasks.map((task) => ({
          text: task.text.trim(),
          status: task.status,
        }));

        if (normalized.some((task) => task.text.length === 0)) {
          throw new Error("Task text cannot be empty");
        }

        const active = normalized.filter((task) => task.status === "in_progress").length;
        if (active > 1) {
          throw new Error("Only one task may be in_progress");
        }

        tasks = normalized;
      }

      const isComplete = tasks.length > 0 && tasks.every((task) => task.status === "completed");
      refreshTaskUI(ctx);
      if (ctx.hasUI && isComplete && !wasComplete) {
        ctx.ui.notify(`✓ All ${tasks.length} tasks completed`, "info");
      }

      return {
        content: [
          {
            type: "text",
            text: tasks.length > 0 ? tasks.map(formatTask).join("\n") : "No tasks",
          },
        ],
        details: { tasks: cloneTasks(tasks) } satisfies TaskDetails,
      };
    },
  });

  pi.registerCommand("tasks", {
    description: "Refresh and show the current task list",
    handler: async (_args, ctx) => {
      refreshTaskUI(ctx);
      if (ctx.hasUI) {
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
