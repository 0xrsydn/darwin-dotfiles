{ pkgs, llm-agents }:
let
  upstream = llm-agents.packages.${pkgs.stdenv.hostPlatform.system}.pi;
  compileCommand = "bun build --compile ./dist/bun/cli.js ./src/utils/image-resize-worker.ts --outfile dist/pi";
in
upstream.overrideAttrs (old: {
  # The standalone binary resolves this exact source path at runtime.
  # The npm source only ships dist/, so create and embed a worker entry.
  # Fail evaluation if the upstream build changes instead of dropping the fix.
  preInstall =
    assert pkgs.lib.hasInfix compileCommand old.preInstall;
    pkgs.lib.replaceStrings
      [ compileCommand ]
      [
        ''
          mkdir -p src/extensions/codemode
          echo 'import "../../../dist/extensions/codemode/worker.js";' > src/extensions/codemode/worker.ts
          bun build --compile ./dist/bun/cli.js ./src/utils/image-resize-worker.ts ./src/extensions/codemode/worker.ts --outfile dist/pi
        ''
      ]
      old.preInstall;

  postInstallCheck = (old.postInstallCheck or "") + ''
    test_home=$(mktemp -d)
    HOME="$test_home" PI_CODING_AGENT_DIR="$test_home/agent" \
      "$out/bin/pi" --offline --no-session --no-extensions --no-skills \
      --no-prompt-templates --no-themes --no-context-files --no-approve \
      --extension ${./pi-codemode-test.ts} --mode rpc < /dev/null > codemode-test.log 2>&1
    tail -n 60 codemode-test.log
    # RPC shutdown can return zero after an extension failure.
    grep -Fx 'codemode regression test passed' codemode-test.log
  '';
})
