{ config, pkgs, lib, ... }: {
  imports = [ ./homebrew.nix ./devtools.nix ];

  services.nix-daemon.enable = true;

  nix = {
    package = pkgs.nix;
    extraOptions = ''
      keep-derivations = true
      keep-outputs = true
    '';
    settings = {
      experimental-features = [ "nix-command" "flakes" ];
      auto-optimise-store = true;
      warn-dirty = false;
    };
    gc = {
      automatic = true;
      interval = {
        Weekday = 0;
        Hour = 3;
        Minute = 30;
      };
      options = "--delete-older-than 30d";
    };
  };

  system = {
    stateVersion = "24.05";

    defaults = {
      NSGlobalDomain = {
        ApplePressAndHoldEnabled = false;
        KeyRepeat = 2;
        InitialKeyRepeat = 15;
      };
      dock = {
        autohide = true;
        show-recents = false;
        tilesize = 48;
      };
      finder = {
        AppleShowAllExtensions = true;
        AppleShowAllFiles = true;
      };
    };
  };

  security.pam.enableSudoTouchIdAuth = true;
}
