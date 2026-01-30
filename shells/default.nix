{ pkgs, ... }:

let
  # MCP wrapper script that ensures Python is available for GUI apps
  mcpNixosWrapper = pkgs.writeShellScriptBin "mcp-nixos-wrapper" ''
    export PATH="${pkgs.python3}/bin:${pkgs.uv}/bin:$PATH"
    exec ${pkgs.uv}/bin/uvx mcp-nixos "$@"
  '';

  # Generate MCP configs for GUI applications
  mcpConfigForGUI = pkgs.writeText "mcp_settings.json" (
    builtins.toJSON {
      mcpServers = {
        nixos = {
          type = "stdio";
          command = "${mcpNixosWrapper}/bin/mcp-nixos-wrapper";
          args = [ ];
        };
      };
    }
  );

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

  # Helper that builds the wrapped Neovim from the flake and runs it with repo-scoped XDG dirs
  previewNvim = pkgs.writeShellScriptBin "preview-nvim" ''
    set -euo pipefail

    root="''${DOTFILES_ROOT:-$PWD}"
    cache_base="$root/.cache"
    nvim_cache="$cache_base/nvim-preview"
    xdg_state="$cache_base/xdg-state"
    xdg_data="$cache_base/xdg-data"
    xdg_config="$root/modules/home/rsydn/programs"

    mkdir -p "$nvim_cache" "$xdg_state" "$xdg_data"

    attr="''${NVIM_ATTR:-}"
    if [ "$#" -gt 0 ]; then
      attr="$1"
      shift
    fi

    if [ -z "$attr" ]; then
      case "$(uname -s)" in
        Darwin)
          attr=".#darwinConfigurations.macbook-pro.config.home-manager.users.rasyidanakbar.programs.neovim.finalPackage"
          ;;
        Linux)
          attr=".#nixosConfigurations.dev-vm.config.home-manager.users.rasyidanakbar.programs.neovim.finalPackage"
          ;;
        *)
          echo "error: unsupported system; pass flake attribute as first argument or set NVIM_ATTR" >&2
          exit 1
          ;;
      esac
    fi

    out_link="$nvim_cache/result"

    echo "Building Neovim package: $attr"
    XDG_CACHE_HOME="$nvim_cache" nix build "$attr" --out-link "$out_link"

    echo "Launching Neovim..."
    XDG_CACHE_HOME="$nvim_cache" \
    XDG_STATE_HOME="$xdg_state" \
    XDG_DATA_HOME="$xdg_data" \
    XDG_CONFIG_HOME="$xdg_config" \
    NVIM_APPNAME="nvim" \
    "$out_link/bin/nvim" "$@"
  '';

in
pkgs.mkShell {
  name = "default";
  packages = with pkgs; [
    git
    nix
    nixfmt
    uv
    python3
    mcpNixosWrapper
    installMcpConfigs
    previewNvim
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
    echo ""
    echo "To preview the Neovim config without switching, run:"
    echo "  preview-nvim [flakeAttr] [-- extra args]"
  '';
}
