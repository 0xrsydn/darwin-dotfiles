{ config, pkgs, lib, ... }:
let
  inherit (lib) mkIf mkOption types;
  cfg = config.rsydn.systemPackages;
in {
  options.rsydn.systemPackages = {
    enable = mkOption {
      type = types.bool;
      default = true;
      description = "Enable system-wide development packages.";
    };

    packages = mkOption {
      type = types.listOf types.package;
      default = with pkgs; [
        ast-grep
        duckdb
        ffmpeg
        fzf
        htop
        jetbrains-mono
        jq
        lazydocker
        lazygit
        lorri
        neovim
        pandoc
        ripgrep
        tree
        vim
        yq
        tmux
        tailscale
        wget
      ];
      description = "System packages to install for development tooling.";
    };
  };

  config = mkIf cfg.enable { environment.systemPackages = cfg.packages; };
}
