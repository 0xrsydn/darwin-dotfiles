# pi-task

A small, session-scoped task list for Pi. It adds one agent tool, `task`, a
compact widget above the editor, and a progress indicator in the footer.

The tool accepts the complete ordered task list, like Claude's todo tool or
Codex's plan tool. The agent adds, updates, removes, or reorders tasks by
submitting a new list. Omitting the list reads the current state; submitting an
empty list clears it.

Statuses are `pending`, `in_progress`, and `completed`. At most one task can be
in progress at a time.

State is stored in Pi tool-result details. It survives reloads and compaction,
follows session branches correctly, and does not create project files. A new Pi
session starts with an empty list. Calls are serialized, and failed or cancelled
calls do not replace the saved list. Invalid saved snapshots are ignored.

While work is active, the widget uses themed symbols and colors to distinguish
the current task (`●`) from pending tasks (`○`). The footer shows compact
overall progress. When every task is complete, Pi displays a success
notification and removes both the widget and footer indicator to reclaim space.
The completed list remains available in session history.

The agent must call `task` to update statuses; finishing code does not update
items automatically. After compaction or two turns without a task call, Pi gives
the agent a short, temporary reminder of open items. If a run ends with open
items, Pi shows a warning. Neither reminder nor warning marks work complete.

Run `/tasks` to refresh the task UI manually. Run the state regression tests
with `node --experimental-strip-types --test pi/extensions/pi-task/state.test.ts`. Pi
loads the deployed extension from Home Manager, so apply the configuration and
reload Pi to use repository changes in normal sessions.
