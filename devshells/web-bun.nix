{ pkgs, ... }:

pkgs.mkShell {
  name = "web-bun";
  packages = with pkgs; [
    bun
    nodejs_20
    yarn
    esbuild
    vscode-langservers-extracted
  ];
  shellHook = ''
    mkdir -p "$PWD/.cache/bun"
    export BUN_INSTALL_CACHE="$PWD/.cache/bun"
    ccusage() { bunx ccusage "$@"; }
    export -f ccusage
    echo "Bun/Node web shell ready"
    echo "Bun: ${pkgs.bun.version}"
    echo "Node: ${pkgs.nodejs_20.version}"
  '';
}
