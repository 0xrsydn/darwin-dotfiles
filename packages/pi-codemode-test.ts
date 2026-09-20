import assert from "node:assert/strict";
import { Type } from "@earendil-works/pi-ai";
import {
  createCodemodeExtension,
  type ExtensionAPI,
  type ExtensionToolContext,
  type ToolDefinition,
} from "@earendil-works/pi-coding-agent";

// Run the embedded sandbox without a model request or provider credentials.
export default function (pi: ExtensionAPI) {
  let codemode: ToolDefinition | undefined;
  createCodemodeExtension({ models: false })({
    ...pi,
    registerTool: (tool) => {
      codemode = tool;
    },
  });

  pi.on("session_start", async (_event, ctx) => {
    try {
      assert.ok(codemode);
      let nestedCalls = 0;
      const toolContext: ExtensionToolContext = {
        ...ctx,
        tools: [
          {
            name: "echo",
            description: "Return the input value.",
            parameters: Type.Object({ value: Type.Number() }),
            outputSchema: Type.Object({ value: Type.Number() }),
          },
        ],
        executeTool: async (name, args) => {
          assert.equal(name, "echo");
          nestedCalls += 1;
          return {
            toolCall: { type: "toolCall", id: `test/${nestedCalls}`, name, arguments: args },
            isError: false,
            result: {
              content: [{ type: "text", text: JSON.stringify(args) }],
              structuredContent: args,
              details: undefined,
            },
          };
        },
      };
      const run = (code: string) =>
        codemode!.execute("codemode-test", { code }, new AbortController().signal, undefined, toolContext);
      const output = (result: Awaited<ReturnType<typeof run>>) =>
        result.content.filter((item) => item.type === "text").map((item) => item.text).join("\n");

      const arithmetic = await run("return 6 * 7;");
      assert.match(output(arithmetic), /Script completed/);
      assert.match(output(arithmetic), /42/);

      const nested = await run(`
        const values = await Promise.all([
          tools.echo({ value: 20 }),
          tools.echo({ value: 22 }),
        ]);
        return values.reduce((sum, item) => sum + item.value, 0);
      `);
      assert.match(output(nested), /Script completed/);
      assert.match(output(nested), /42/);
      assert.equal(nestedCalls, 2);

      const failure = await run('throw new Error("expected-test-error");');
      assert.match(output(failure), /Script failed/);
      assert.match(output(failure), /expected-test-error/);
      console.error("codemode regression test passed");
    } catch (error) {
      console.error(error);
      process.exitCode = 1;
    } finally {
      ctx.shutdown();
    }
  });
}
