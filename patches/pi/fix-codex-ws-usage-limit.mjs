// Patches @earendil-works/pi-ai's openai-codex-responses provider so that
// usage-limit errors arriving over the WebSocket transport are mapped to the
// same friendly "You have hit your ChatGPT usage limit" message that the
// SSE/fetch path already produces via parseErrorResponse().
//
// Without this, the default `transport: auto` (WebSocket-first) path throws
// the raw upstream string verbatim, e.g.:
//   "You exceeded your current quota, please check your plan and billing
//    details. For more information on this error, read the docs:
//    https://platform.openai.com/docs/guides/error-codes/api-errors."
// which is misleading: the account is a ChatGPT subscription (prolite plan),
// not API billing, and the real limit is a per-window ChatGPT/Codex quota.
//
// Usage: node fix-codex-ws-usage-limit.mjs <path-to-openai-codex-responses.js>
import { readFileSync, writeFileSync } from "node:fs";

const file = process.argv[2];
if (!file) {
  console.error("fix-codex-ws-usage-limit: missing target file argument");
  process.exit(1);
}

let src = readFileSync(file, "utf8");

// 1. Insert a friendly-message helper just before mapCodexEvents.
const helperAnchor = "async function* mapCodexEvents(events) {";
if (!src.includes(helperAnchor)) {
  console.error(
    "fix-codex-ws-usage-limit: anchor 'async function* mapCodexEvents(events) {' not found; refusing to patch an unfamiliar file.",
  );
  process.exit(2);
}

const helper = `function friendlyCodexUsageMessage(code, message, payload) {
    const codeStr = typeof code === "string" ? code : "";
    const msgStr = typeof message === "string" ? message : "";
    const isUsageLimit =
        /usage_limit_reached|usage_not_included|rate_limit_exceeded/i.test(codeStr) ||
        /insufficient_quota|exceeded your current quota|quota exceeded|out of budget|usage limit|billing/i.test(msgStr);
    if (!isUsageLimit)
        return undefined;
    const src = (payload && typeof payload === "object")
        ? (payload.response?.error ?? payload.error ?? payload)
        : {};
    const plan = src.plan_type ? \` (\${String(src.plan_type).toLowerCase()} plan)\` : "";
    const resetsAt = src.resets_at ?? payload?.resets_at;
    const mins = typeof resetsAt === "number"
        ? Math.max(0, Math.round((resetsAt * 1000 - Date.now()) / 60000))
        : undefined;
    const when = mins !== undefined ? \` Try again in ~\${mins} min.\` : "";
    return \`You have hit your ChatGPT usage limit\${plan}.\${when}\`.trim();
}
`;

if (!src.includes("function friendlyCodexUsageMessage(")) {
  src = src.replace(helperAnchor, helper + helperAnchor);
}

// 2. Map usage-limit errors in the `error` event branch.
const errorBranchOld = `        if (type === "error") {
            const code = event.code || "";
            const message = event.message || "";
            throw new CodexApiError(\`Codex error: \${message || code || JSON.stringify(event)}\`, {
                code: code || undefined,
                payload: event,
            });
        }`;
const errorBranchWithExtractorOld = `        if (type === "error") {
            const { code, message } = extractCodexEventError(event);
            throw new CodexApiError(\`Codex error: \${message || code || JSON.stringify(event)}\`, {
                code,
                payload: event,
            });
        }`;
const errorBranchNew = `        if (type === "error") {
            const code = event.code || "";
            const message = event.message || "";
            const friendly = friendlyCodexUsageMessage(code, message, event);
            throw new CodexApiError(friendly || \`Codex error: \${message || code || JSON.stringify(event)}\`, {
                code: code || undefined,
                payload: event,
            });
        }`;
const errorBranchWithExtractorNew = `        if (type === "error") {
            const { code, message } = extractCodexEventError(event);
            const friendly = friendlyCodexUsageMessage(code, message, event);
            throw new CodexApiError(friendly || \`Codex error: \${message || code || JSON.stringify(event)}\`, {
                code,
                payload: event,
            });
        }`;
if (src.includes(errorBranchOld)) {
  src = src.replace(errorBranchOld, errorBranchNew);
} else if (src.includes(errorBranchWithExtractorOld)) {
  src = src.replace(errorBranchWithExtractorOld, errorBranchWithExtractorNew);
} else if (!src.includes("const friendly = friendlyCodexUsageMessage(code, message, event);")) {
  console.error("fix-codex-ws-usage-limit: could not locate the 'error' event throw branch; refusing to patch.");
  process.exit(3);
}

// 3. Map usage-limit errors in the `response.failed` event branch.
const failedBranchOld = `        if (type === "response.failed") {
            const response = event.response;
            const code = response?.error?.code;
            const message = response?.error?.message;
            throw new CodexApiError(message || "Codex response failed", { code, payload: event });
        }`;
const failedBranchNew = `        if (type === "response.failed") {
            const response = event.response;
            const code = response?.error?.code;
            const message = response?.error?.message;
            const friendly = friendlyCodexUsageMessage(code || "", message || "", event);
            throw new CodexApiError(friendly || message || "Codex response failed", { code, payload: event });
        }`;
if (src.includes(failedBranchOld)) {
  src = src.replace(failedBranchOld, failedBranchNew);
} else if (!src.includes('const friendly = friendlyCodexUsageMessage(code || "", message || "", event);')) {
  console.error("fix-codex-ws-usage-limit: could not locate the 'response.failed' throw branch; refusing to patch.");
  process.exit(4);
}

writeFileSync(file, src);
console.error("fix-codex-ws-usage-limit: patched " + file);
