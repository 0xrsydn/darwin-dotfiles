{ pkgs, ... }:

pkgs.mkShell {
  name = "default";
  packages = with pkgs; [ git nixfmt-classic uv ];
  shellHook = ''
    export DOTFILES_ROOT="$PWD"
    export XDG_CACHE_HOME="$DOTFILES_ROOT/.cache"
    export UV_CACHE_DIR="$XDG_CACHE_HOME/uv"
    export UV_TOOL_HOME="$XDG_CACHE_HOME/uv-tools"
    export XDG_DATA_HOME="$DOTFILES_ROOT/.cache/xdg-data"
    export UV_PYTHON_DOWNLOADS=never
    export MCP_CONFIG_PATH="$DOTFILES_ROOT/.mcp.json"

    mkdir -p "$XDG_CACHE_HOME" "$UV_CACHE_DIR" "$UV_TOOL_HOME" "$XDG_DATA_HOME"

    alias mcp-nixos='XDG_CACHE_HOME="$XDG_CACHE_HOME" XDG_DATA_HOME="$XDG_DATA_HOME" UV_CACHE_DIR="$UV_CACHE_DIR" UV_TOOL_HOME="$UV_TOOL_HOME" UV_PYTHON_DOWNLOADS="$UV_PYTHON_DOWNLOADS" uvx mcp-nixos'

    echo "Loaded default shell for dotfiles development"
    echo "MCP helper alias ready: mcp-nixos"
  '';
}
