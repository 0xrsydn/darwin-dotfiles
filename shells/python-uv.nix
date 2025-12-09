{ pkgs, python ? pkgs.python312, ... }:

pkgs.mkShell {
  name = "python-uv";
  packages = [ python pkgs.uv pkgs.ruff pkgs.pyright ];
  shellHook = ''
    export UV_PYTHON="${python}/bin/python3"
    export UV_LINK_MODE=copy
    echo "Python (uv) shell ready"
    echo "Python: ${python.version}"
  '';
}
