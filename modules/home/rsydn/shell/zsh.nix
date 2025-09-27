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
      description =
        "Prompt theme identifier (powerlevel10k supported out of the box).";
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
      description =
        "Additional script appended after the standard zsh setup runs.";
    };

    promptInit = mkOption {
      type = types.lines;
      default = "";
      description =
        "Custom prompt initialization snippet appended after theme setup.";
    };

    powerlevel10kConfigFile = mkOption {
      type = types.nullOr types.path;
      default = null;
      description =
        "Optional path to a Powerlevel10k config that will be linked to ~/.p10k.zsh.";
    };

    enableAutoSuggestion = mkOption {
      type = types.bool;
      default = true;
      description = "Enable zsh-autosuggestions.";
    };

    autosuggestAcceptWidgets = mkOption {
      type = types.listOf types.str;
      default = [
        "forward-char"
        "end-of-line"
        "vi-forward-char"
        "vi-end-of-line"
        "vi-add-eol"
        "expand-or-complete"
        "complete-word"
        "fzf-completion"
      ];
      description = "Widgets that should accept autosuggestions before running (ZSH_AUTOSUGGEST_ACCEPT_WIDGETS).";
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
        initContent = lib.mkAfter cfg.extraAfter;
        localVariables = lib.mkIf cfg.enableAutoSuggestion {
          ZSH_AUTOSUGGEST_ACCEPT_WIDGETS = cfg.autosuggestAcceptWidgets;
        };
      };
    }
    { programs.zsh.initContent = lib.mkOrder 550 cfg.extraBeforeCompInit; }
    (mkIf (cfg.theme == "powerlevel10k/powerlevel10k") {
      programs.zsh.initExtraFirst = lib.mkBefore ''
        source ${pkgs.zsh-powerlevel10k}/share/zsh-powerlevel10k/powerlevel10k.zsh-theme
      '';
    })
    (mkIf (cfg.powerlevel10kConfigFile != null) {
      home.file.".p10k.zsh".source = cfg.powerlevel10kConfigFile;
      programs.zsh.initExtraFirst = lib.mkAfter ''
        source ~/.p10k.zsh
      '';
    })
    (mkIf (cfg.promptInit != "") {
      programs.zsh.initExtraFirst = lib.mkAfter cfg.promptInit;
    })
    (mkIf cfg.enableVimMode {
      programs.zsh.initContent = lib.mkBefore ''
        bindkey -v
      '';
    })
  ]);
}
