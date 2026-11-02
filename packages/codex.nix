{ pkgs, llm-agents }:
let
  system = pkgs.stdenv.hostPlatform.system;
  upstream =
    if builtins.hasAttr system llm-agents.packages then
      llm-agents.packages.${system}.codex
    else
      throw "codex: llm-agents does not provide packages.${system} (supported: ${builtins.concatStringsSep ", " (builtins.attrNames llm-agents.packages)})";
  manifest = pkgs.writeText "codex-package.json" (
    builtins.toJSON {
      layoutVersion = 1;
      version = upstream.version;
      target = pkgs.stdenv.hostPlatform.rust.rustcTarget;
      entrypoint = "bin/codex";
    }
  );
in
# Temporary adapter for Numtide's source build. Remove when upstream supplies
# the complete daemon package layout. Reuse binaries without rebuilding Rust.
pkgs.runCommand "codex-${upstream.version}"
  {
    inherit (upstream) version meta;
    nativeBuildInputs = [ pkgs.python3 ];
    passthru = { inherit upstream; };
  }
  ''
    mkdir -p "$out/bin" "$out/codex-path"
    source=${upstream}/bin
    if [ -d ${upstream}/libexec/codex/bin ]; then
      source=${upstream}/libexec/codex/bin
    fi
    # Copy real executables: daemon provisioning rejects escaping symlinks.
    cp -L "$source/codex" "$source/codex-code-mode-host" "$source/logs_client" "$out/bin/"
    cp -L ${pkgs.ripgrep}/bin/rg "$out/codex-path/rg"
    cp ${manifest} "$out/codex-package.json"
    ${pkgs.lib.optionalString pkgs.stdenv.hostPlatform.isLinux ''
      mkdir -p "$out/codex-resources"
      cp -L ${pkgs.bubblewrap}/bin/bwrap "$out/codex-resources/bwrap"
    ''}
    cp -RL ${upstream}/share "$out/share"
    python ${./codex-package-test.py} "$out" '${upstream.version}' '${pkgs.stdenv.hostPlatform.rust.rustcTarget}'
    "$out/bin/codex" --version
  ''
