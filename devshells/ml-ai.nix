{ pkgs, python ? pkgs.python312, ... }:

let
  # Create a Python environment with huggingface-cli
  pythonWithHF = python.withPackages (ps: [ ps.huggingface-hub ]);
in pkgs.mkShell {
  name = "ml-ai";
  packages = with pkgs; [ pythonWithHF uv git-lfs ruff pyright ];
  shellHook = ''
    # Set up UV
    export UV_PYTHON="${pythonWithHF}/bin/python3"
    export UV_LINK_MODE=copy

    # Set up HuggingFace cache (persistent across projects)
    export HF_HOME="''${XDG_CACHE_HOME:-$HOME/.cache}/huggingface"
    export HF_HUB_CACHE="$HF_HOME/hub"
    mkdir -p "$HF_HOME"

    # Optional: Set offline mode (uncomment to use only cached models)
    # export HF_HUB_OFFLINE=1

    echo "ML/AI shell ready"
    echo "Python: ${python.version}"
    echo "HuggingFace cache: $HF_HOME"
    echo ""
    echo "Download models with:"
    echo "  huggingface-cli download <model-id>"
    echo ""
    echo "Example TTS:"
    echo "  huggingface-cli download facebook/mms-tts-eng"
    echo ""
    echo "Example LLM:"
    echo "  huggingface-cli download meta-llama/Llama-3.2-1B"
  '';
}
