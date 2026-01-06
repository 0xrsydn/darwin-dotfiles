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
      default = [ "FelixKratz/formulae" ];
      description = "Homebrew taps to add.";
    };
    brews = mkOption {
      type = types.listOf types.str;
      default = [ "curl" "yt-dlp" "infisical" "mole" ];
      description = "Homebrew formulae to install.";
    };
    casks = mkOption {
      type = types.listOf types.str;
      default = [
        "bitwarden"
        "brave-browser"
        "firefox"
        "font-jetbrains-mono"
        "pgadmin4"
        "spotify"
        "vesktop"
        "obs"
        "neohtop"
        "orbstack"
        "ghostty"
        "openvpn-connect"
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
