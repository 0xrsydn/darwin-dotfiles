{ pkgs, ... }:

let
  # MCP wrapper script that ensures Python is available for GUI apps
  mcpNixosWrapper = pkgs.writeShellScriptBin "mcp-nixos-wrapper" ''
    export PATH="${pkgs.python3}/bin:${pkgs.uv}/bin:$PATH"
    exec ${pkgs.uv}/bin/uvx mcp-nixos "$@"
  '';

  # Generate MCP configs for GUI applications
  mcpConfigForGUI = pkgs.writeText "mcp_settings.json" (builtins.toJSON {
    mcpServers = {
      nixos = {
        type = "stdio";
        command = "${mcpNixosWrapper}/bin/mcp-nixos-wrapper";
        args = [ ];
      };
    };
  });

  # Script to install MCP configs for Claude Code and Codex
  installMcpConfigs = pkgs.writeShellScriptBin "install-mcp-configs" ''
    set -e
    echo "Installing MCP configurations..."

    mkdir -p "$HOME/.config/claude-code"
    mkdir -p "$HOME/.config/codex"

    cp ${mcpConfigForGUI} "$HOME/.config/claude-code/mcp_settings.json"
    cp ${mcpConfigForGUI} "$HOME/.config/codex/mcp_settings.json"

    echo "✓ Installed MCP config to ~/.config/claude-code/mcp_settings.json"
    echo "✓ Installed MCP config to ~/.config/codex/mcp_settings.json"
    echo ""
    echo "Restart Claude Code and Codex to apply changes."
  '';

in pkgs.mkShell {
  name = "default";
  packages = with pkgs; [
    git
    nixfmt-classic
    uv
    python3
    mcpNixosWrapper
    installMcpConfigs
  ];
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
    echo ""
    echo "To install MCP configs for Claude Code and Codex, run:"
    echo "  install-mcp-configs"
  '';
}
