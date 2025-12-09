{ pkgs, ... }:

pkgs.mkShell {
  name = "rust";
  packages = with pkgs; [ cargo rustc rust-analyzer rustfmt clippy ];
  shellHook = ''
    mkdir -p "$PWD/.cache/cargo"
    export CARGO_HOME="$PWD/.cache/cargo"
    echo "Rust toolchain shell ready"
    echo "Rust: ${pkgs.rustc.version}"
  '';
}
