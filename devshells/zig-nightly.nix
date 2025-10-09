{ pkgs, lib, zigPackage, ... }:

lib.optionalAttrs (zigPackage != null) (pkgs.mkShell {
  name = "zig-nightly";
  packages = [ zigPackage pkgs.zls pkgs.pkg-config pkgs.cmake pkgs.gdb ];
  shellHook = ''
    mkdir -p "$PWD/.cache/zig"
    export ZIG_GLOBAL_CACHE_DIR="$PWD/.cache/zig"
    echo "Zig shell using ${zigPackage.pname or "zig"} ${
      zigPackage.version or ""
    }"
  '';
})
