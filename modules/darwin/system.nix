{ config, pkgs, lib, user, ... }: {
  imports = [ ./homebrew.nix ./devtools.nix ];

  nix = {
    extraOptions = ''
      keep-derivations = true
      keep-outputs = true
    '';
    settings = {
      experimental-features = [ "nix-command" "flakes" ];
      warn-dirty = false;
      # Numtide binary cache for llm-agents.nix packages
      extra-substituters = [ "https://cache.numtide.com" ];
      extra-trusted-public-keys =
        [ "numtide.cachix.org-1:2ps1kLBUWjxIneOy1Ber8L+2z9FqRZJ+KBKGE4NNsT0=" ];
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

  environment.shells = [ pkgs.nushell "/etc/profiles/per-user/${user}/bin/nu" ];

  # Set XDG Base Directory environment variables globally
  # This ensures nushell and other XDG-compliant tools use ~/.config
  environment.variables = {
    XDG_CONFIG_HOME = "$HOME/.config";
    XDG_DATA_HOME = "$HOME/.local/share";
    XDG_CACHE_HOME = "$HOME/.cache";
  };

  users.users.${user} = {
    home = lib.mkDefault "/Users/${user}";
    # Use the Home Manager nushell which has proper config setup
    shell = "/etc/profiles/per-user/${user}/bin/nu";
  };

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
