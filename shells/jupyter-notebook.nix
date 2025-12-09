{ pkgs, python ? pkgs.python312, ... }:

let
  # Python environment with notebook tooling and core data-science libs
  pythonWithNotebook = python.withPackages (ps:
    with ps; [
      altair
      ipykernel
      jupyterlab
      matplotlib
      numpy
      pandas
      polars
      plotly
      scipy
      scikit-learn
      seaborn
    ]);
in pkgs.mkShell {
  name = "jupyter-notebook";
  packages = [ pythonWithNotebook pkgs.ruff pkgs.pyright pkgs.git ];
  shellHook = ''
    export PYTHONNOUSERSITE=1
    export JUPYTER_CONFIG_DIR="''${XDG_CONFIG_HOME:-$HOME/.config}/jupyter"
    mkdir -p "$JUPYTER_CONFIG_DIR"
    echo "Jupyter notebook shell ready"
    echo "Python: ${python.version}"
    echo "Launch notebook: jupyter lab"
    echo "Launch classic: jupyter notebook"
  '';
}
