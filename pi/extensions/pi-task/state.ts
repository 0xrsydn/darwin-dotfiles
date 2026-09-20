export type TaskStatus = "pending" | "in_progress" | "completed";

export interface Task {
  text: string;
  status: TaskStatus;
}

export interface TaskDetails {
  tasks: Task[];
}

export function cloneTasks(tasks: Task[]): Task[] {
  return tasks.map((task) => ({ ...task }));
}

export function normalizeTasks(tasks: Task[]): Task[] {
  const normalized = tasks.map((task) => ({ text: task.text.trim(), status: task.status }));
  if (normalized.some((task) => task.text.length === 0)) {
    throw new Error("Task text cannot be empty");
  }
  if (normalized.filter((task) => task.status === "in_progress").length > 1) {
    throw new Error("Only one task may be in_progress");
  }
  return normalized;
}

export function restoreTasks(
  entries: Iterable<{ type: string; message?: { role: string; toolName?: string; isError?: boolean; details?: unknown } }>,
): Task[] {
  let tasks: Task[] = [];
  for (const entry of entries) {
    if (entry.type !== "message") continue;
    const message = entry.message;
    if (message?.role !== "toolResult" || message.toolName !== "task" || message.isError) continue;
    const saved = message.details as TaskDetails | undefined;
    if (!saved || !Array.isArray(saved.tasks)) continue;
    try {
      if (saved.tasks.some((task) =>
        !task || typeof task.text !== "string" ||
        !["pending", "in_progress", "completed"].includes(task.status)
      )) continue;
      tasks = normalizeTasks(saved.tasks);
    } catch {
      // Ignore malformed snapshots; preserve the last valid state on this branch.
    }
  }
  return tasks;
}

/** Serializes calls and rejects calls queued before a branch or session change. */
export class TaskStore {
  private tasks: Task[] = [];
  private generation = 0;
  private tail: Promise<void> = Promise.resolve();

  read(): Task[] {
    return cloneTasks(this.tasks);
  }

  restore(entries: Parameters<typeof restoreTasks>[0]): void {
    this.generation++;
    this.tasks = restoreTasks(entries);
  }

  async call(next: Task[] | undefined, signal?: AbortSignal): Promise<{ tasks: Task[]; wasComplete: boolean }> {
    const generation = this.generation;
    const previous = this.tail;
    let release!: () => void;
    this.tail = new Promise<void>((resolve) => { release = resolve; });
    await previous;
    try {
      if (generation !== this.generation || signal?.aborted) {
        throw new Error("Task call cancelled or session changed");
      }
      const normalized = next === undefined ? undefined : normalizeTasks(next);
      const wasComplete = this.tasks.length > 0 && this.tasks.every((task) => task.status === "completed");
      if (normalized) this.tasks = normalized;
      return { tasks: this.read(), wasComplete };
    } finally {
      release();
    }
  }
}
