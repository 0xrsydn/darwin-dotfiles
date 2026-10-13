import type { ExtensionAPI, ExtensionContext } from "@earendil-works/pi-coding-agent";
import {
  FAST_STATE_ENTRY,
  isCodexModel,
  parseFastCommand,
  patchFastPayload,
  restoreFastMode,
} from "./state.ts";

export default function openaiCodexFast(pi: ExtensionAPI) {
  let enabled = false;

  function updateStatus(ctx: ExtensionContext, model = ctx.model): void {
    if (!ctx.hasUI) return;
    ctx.ui.setStatus(
      FAST_STATE_ENTRY,
      enabled && isCodexModel(model) ? "Codex fast: priority" : undefined,
    );
  }

  function restore(ctx: ExtensionContext): void {
    enabled = restoreFastMode(ctx.sessionManager.getBranch());
    updateStatus(ctx);
  }

  pi.on("session_start", (_event, ctx) => restore(ctx));
  pi.on("session_tree", (_event, ctx) => restore(ctx));
  pi.on("model_select", (event, ctx) => updateStatus(ctx, event.model));

  pi.on("before_provider_request", (event, ctx) =>
    patchFastPayload({ enabled, model: ctx.model, payload: event.payload }),
  );

  pi.registerCommand("fast", {
    description: "Toggle Codex priority service. Usage: /fast [on|off|status]. May increase usage.",
    handler: async (args, ctx) => {
      const command = parseFastCommand(args);
      if (!command) {
        ctx.ui.notify("Usage: /fast [on|off|status]", "warning");
        return;
      }
      if (command === "status") {
        const state = enabled
          ? isCodexModel(ctx.model) ? "on, requesting priority service" : "on, inactive for this provider"
          : "off, using provider defaults";
        ctx.ui.notify(`Codex fast mode is ${state}.`, "info");
        return;
      }
      if (!ctx.isIdle()) {
        ctx.ui.notify("Wait for the current turn to finish before changing fast mode.", "warning");
        return;
      }
      const next = command === "toggle" ? !enabled : command === "on";
      if (next && !isCodexModel(ctx.model)) {
        ctx.ui.notify("Fast mode requires the openai-codex provider and openai-codex-responses API.", "warning");
        return;
      }
      if (next !== enabled) {
        pi.appendEntry(FAST_STATE_ENTRY, { enabled: next });
        enabled = next;
      }
      updateStatus(ctx);
      ctx.ui.notify(
        enabled
          ? "Codex fast mode on. Requesting priority service; usage may increase. OpenAI controls availability."
          : "Codex fast mode off. Using provider defaults.",
        "info",
      );
    },
  });
}
