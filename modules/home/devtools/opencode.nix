{ config, lib, pkgs, customPkgs, ... }:
let
  inherit (lib) mkEnableOption mkOption types mkIf;
  cfg = config.rsydn.opencode;

  # Build the config JSON, filtering out null/empty values
  opencodeConfig = lib.filterAttrs (_: v: v != null && v != { }) {
    "$schema" = "https://opencode.ai/config.json";
    theme = cfg.theme;
    model = cfg.model;
    small_model = cfg.smallModel;
    autoupdate = false; # Nix manages updates
    mcp = if cfg.mcpServers != { } then cfg.mcpServers else null;
    keybinds = if cfg.keybinds != { } then cfg.keybinds else null;
  };
in {
  options.rsydn.opencode = {
    enable = mkEnableOption "OpenCode CLI with managed configuration";

    package = mkOption {
      type = types.nullOr types.package;
      default = customPkgs.opencode;
      description = ''
        OpenCode package to use. Defaults to the custom-built package
        from packages/opencode.nix via customPkgs.
      '';
    };

    theme = mkOption {
      type = types.str;
      default = "catppuccin";
      description = "UI theme for OpenCode TUI";
    };

    model = mkOption {
      type = types.str;
      default = "anthropic/claude-sonnet-4-5";
      description = "Primary LLM model identifier";
    };

    smallModel = mkOption {
      type = types.str;
      default = "anthropic/claude-haiku-3-5";
      description = "Lightweight model for tasks like title generation";
    };

    mcpServers = mkOption {
      type = types.attrs;
      default = { };
      example = {
        nixos = {
          type = "stdio";
          command = "uvx";
          args = [ "mcp-nixos" ];
        };
      };
      description = "MCP server configurations";
    };

    keybinds = mkOption {
      type = types.attrs;
      default = { };
      description = "Custom keybinding overrides";
    };

    # Future extension points (joelhooks-style)
    agents = mkOption {
      type = types.attrsOf types.path;
      default = { };
      description = ''
        Custom agent markdown files.
        Keys become filenames under ~/.config/opencode/agent/
      '';
    };

    commands = mkOption {
      type = types.attrsOf types.path;
      default = { };
      description = ''
        Custom command markdown files.
        Keys become filenames under ~/.config/opencode/command/
      '';
    };

    extraConfig = mkOption {
      type = types.attrs;
      default = { };
      description = "Additional config options to merge into opencode.json";
    };
  };

  config = mkIf cfg.enable {
    home.packages = lib.optional (cfg.package != null) cfg.package;

    xdg.configFile = {
      # Global config file
      "opencode/opencode.json".text =
        builtins.toJSON (opencodeConfig // cfg.extraConfig);
    } // lib.mapAttrs' (name: path:
      # Agent markdown files
      lib.nameValuePair "opencode/agent/${name}.md" { source = path; })
      cfg.agents // lib.mapAttrs' (name: path:
        # Command markdown files
        lib.nameValuePair "opencode/command/${name}.md" { source = path; })
      cfg.commands;
  };
}
