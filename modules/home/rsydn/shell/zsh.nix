{ config, lib, pkgs, ... }:
let
  inherit (lib) mkEnableOption mkIf mkMerge mkOption types;
  cfg = config.rsydn.shell.zsh;
in {
  options.rsydn.shell.zsh = {
    enable = mkEnableOption "user zsh configuration managed by Home Manager";

    theme = mkOption {
      type = types.str;
      default = "powerlevel10k/powerlevel10k";
      description = "Oh My Zsh theme name.";
    };

    plugins = mkOption {
      type = types.listOf types.str;
      default = [ ];
      description = "Oh My Zsh plugins to load.";
    };

    aliases = mkOption {
      type = types.attrsOf types.str;
      default = { };
      description = "Zsh command aliases.";
    };

    extraBeforeCompInit = mkOption {
      type = types.lines;
      default = ''
        if [[ -r "''${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-''${(%):-%n}.zsh" ]]; then
          source "''${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-''${(%):-%n}.zsh"
        fi
      '';
      description =
        "Extra script executed before compinit (useful for instant prompt).";
    };

    extraAfter = mkOption {
      type = types.lines;
      default = "";
      description = "Additional script appended after Oh My Zsh loads.";
    };

    enableAutoSuggestion = mkOption {
      type = types.bool;
      default = true;
      description = "Enable zsh-autosuggestions.";
    };

    enableSyntaxHighlighting = mkOption {
      type = types.bool;
      default = true;
      description = "Enable zsh-syntax-highlighting.";
    };

    enableVimMode = mkOption {
      type = types.bool;
      default = false;
      description = "Enable vi keybindings by running bindkey -v.";
    };
  };

  config = mkIf cfg.enable (mkMerge [
    {
      programs.zsh = {
        enable = true;
        enableCompletion = true;
        autosuggestion.enable = cfg.enableAutoSuggestion;
        syntaxHighlighting.enable = cfg.enableSyntaxHighlighting;
        shellAliases = cfg.aliases;
        initExtra = cfg.extraAfter;

        oh-my-zsh = {
          enable = true;
          theme = cfg.theme;
          plugins = cfg.plugins;
        };
      };
    }
    {
      programs.zsh.initContent = lib.mkOrder 550 cfg.extraBeforeCompInit;
    }
    (mkIf cfg.enableVimMode {
      programs.zsh.initContent = lib.mkBefore ''
        bindkey -v
      '';
    })
  ]);
}
