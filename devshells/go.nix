{ pkgs, ... }:

pkgs.mkShell {
  name = "go";
  packages = with pkgs; [ go gopls golangci-lint delve git ];
  shellHook = ''
    mkdir -p "$PWD/.cache/go" "$PWD/.cache/gomod"
    export GOPATH="$PWD/.cache/go"
    export GOMODCACHE="$PWD/.cache/gomod"
    echo "Go toolchain shell ready"
    echo "Go: ${pkgs.go.version}"
  '';
}
