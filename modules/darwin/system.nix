{ config, pkgs, lib, user, ... }: {
  imports = [ ./homebrew.nix ./devtools.nix ];

  nix = {
    package = pkgs.nix;
    extraOptions = ''
      keep-derivations = true
      keep-outputs = true
    '';
    settings = {
      experimental-features = [ "nix-command" "flakes" ];
      warn-dirty = false;
    };
    optimise.automatic = true;
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

  environment.shells = [ pkgs.nushell ];

  users.users.${user}.shell = pkgs.nushell;

  system = {
    primaryUser = user;
    stateVersion = 6;

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

  security.pam.services.sudo_local.touchIdAuth = true;
}
