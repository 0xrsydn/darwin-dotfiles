{ config, lib, ... }:
let
  inherit (lib) mkIf mkOption types;
  cfg = config.rsydn.homebrew;
in {
  options.rsydn.homebrew = {
    enable = mkOption {
      type = types.bool;
      default = true;
      description = "Whether to manage Homebrew declaratively.";
    };
    taps = mkOption {
      type = types.listOf types.str;
      default = [ ];
      description = "Homebrew taps to add.";
    };
    brews = mkOption {
      type = types.listOf types.str;
      default = [
        "curl"
        "yt-dlp"
        "nodejs"
        "ruff"
        "libmagic"
        "ghostscript"
        "infisical"
        "fastfetch"
      ];
      description = "Homebrew formulae to install.";
    };
    casks = mkOption {
      type = types.listOf types.str;
      default = [
        "bitwarden"
        "chromium"
        "dbngin"
        "pgadmin4"
        "docker-desktop"
        "spotify"
        "discord"
        "obs"
        "neohtop"
        "orbstack"
        "visual-studio-code"
        "google-chrome@canary"
        "mactex"
        "ghostty"
      ];
      description = "Homebrew casks to install.";
    };
  };

  config = mkIf cfg.enable {
    homebrew = {
      enable = true;
      global.autoUpdate = false;
      onActivation = {
        autoUpdate = false;
        cleanup = "zap";
        upgrade = false;
      };
      inherit (cfg) taps brews casks;
    };
  };
}
