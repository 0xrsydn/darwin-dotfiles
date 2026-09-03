{
  config,
  pkgs,
  lib,
  user,
  ...
}:
{
  imports = [
    ./homebrew.nix
    ./devtools.nix
  ];

  nix = {
    # Use default nix version from nixpkgs (don't pin to avoid rebuild issues)
    extraOptions = ''
      keep-derivations = true
      keep-outputs = true
    '';
    settings = {
      experimental-features = [
        "nix-command"
        "flakes"
      ];
      warn-dirty = false;
      # Numtide binary cache for llm-agents.nix packages
      extra-substituters = [ "https://cache.numtide.com" ];
      extra-trusted-public-keys = [ "niks3.numtide.com-1:DTx8wZduET09hRmMtKdQDxNNthLQETkc/yaX7M4qK0g=" ];
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

  environment.shells = [
    pkgs.nushell
    "/etc/profiles/per-user/${user}/bin/nu"
  ];

  # Set XDG Base Directory environment variables globally
  # This ensures nushell and other XDG-compliant tools use ~/.config
  environment.variables = {
    XDG_CONFIG_HOME = "$HOME/.config";
    XDG_DATA_HOME = "$HOME/.local/share";
    XDG_CACHE_HOME = "$HOME/.cache";
  };

  users.users.${user}.home = lib.mkDefault "/Users/${user}";

  system = {
    primaryUser = user;
    stateVersion = 6;

    # nix-darwin does not manage an existing primary user unless the user is in
    # users.knownUsers. Manage only the login shell to avoid owning the account.
    activationScripts.postActivation.text = lib.mkAfter ''
      current_shell=$(
        /usr/bin/dscl . -read ${lib.escapeShellArg "/Users/${user}"} UserShell 2>/dev/null \
          | /usr/bin/awk '{ print $2 }' \
          || true
      )

      if [ "$current_shell" != "/bin/zsh" ]; then
        echo "setting ${user}'s login shell to /bin/zsh..." >&2
        /usr/bin/dscl . -create ${lib.escapeShellArg "/Users/${user}"} UserShell /bin/zsh
      fi
    '';

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
