{ pkgs, lib, python ? pkgs.python312, ... }:

let
  pythonWithAI = python.withPackages (ps:
    let
      basePackages = with ps; [
        accelerate
        albumentations
        altair
        datasets
        evaluate
        huggingface-hub
        ipykernel
        jupyterlab
        matplotlib
        numpy
        opencv4
        pandas
        pillow
        plotly
        scipy
        scikit-image
        scikit-learn
        seaborn
        sentencepiece
        tokenizers
        transformers
      ];
      linuxOnlyPackages = lib.optionals pkgs.stdenv.isLinux
        (with ps; [ torch torchaudio torchvision ]);
    in basePackages ++ linuxOnlyPackages);
in pkgs.mkShell {
  name = "ai-notebook";
  packages = with pkgs; [ pythonWithAI uv git-lfs ruff pyright ];

  shellHook = ''
    export UV_PYTHON="${pythonWithAI}/bin/python3"
    export UV_LINK_MODE=copy

    export PYTHONNOUSERSITE=1
    export HF_HOME="''${XDG_CACHE_HOME:-$HOME/.cache}/huggingface"
    export HF_HUB_CACHE="$HF_HOME/hub"
    export TRANSFORMERS_CACHE="$HF_HOME/transformers"
    export JUPYTER_CONFIG_DIR="''${XDG_CONFIG_HOME:-$HOME/.config}/jupyter"

    mkdir -p "$HF_HOME" "$JUPYTER_CONFIG_DIR"

    echo "AI notebook shell ready"
    echo "Python: ${python.version}"
    echo "HuggingFace cache: $HF_HOME"
    echo "Launch JupyterLab: jupyter lab"
    echo "Launch classic notebook: jupyter notebook"
  '';
}
