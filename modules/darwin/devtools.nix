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
        go
        htop
        jetbrains-mono
        jq
        lazydocker
        lazygit
        lorri
        neovim
        pandoc
        postgresql_18
        python312
        python312Packages.uv
        ripgrep
        rustc
        rustup
        tree
        vim
        yq
        tmux
        tailscale
        sqlite
        wget
      ];
      description = "System packages to install for development tooling.";
    };
  };

  config = mkIf cfg.enable { environment.systemPackages = cfg.packages; };
}
