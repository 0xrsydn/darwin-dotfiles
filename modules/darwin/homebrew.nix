{
  config,
  lib,
  pkgs,
  user,
  ...
}:
let
  inherit (lib)
    mkIf
    mkOption
    mkAfter
    types
    ;
  cfg = config.rsydn.homebrew;
  userHome = config.users.users.${user}.home;
in
{
  options.rsydn.homebrew = {
    enable = mkOption {
      type = types.bool;
      default = true;
      description = "Whether to manage Homebrew declaratively.";
    };
    taps = mkOption {
      type = types.listOf types.str;
      default = [
        "FelixKratz/formulae"
        "owo-network/brew"
      ];
      description = "Homebrew taps to add.";
    };
    brews = mkOption {
      type = types.listOf types.str;
      default = [
        "curl"
        "yt-dlp"
        "infisical"
        "mole"
      ];
      description = "Homebrew formulae to install.";
    };
    casks = mkOption {
      type = types.listOf types.str;
      default = [
        "bitwarden"
        "brave-browser"
        "font-jetbrains-mono"
        "pgadmin4"
        "spotify"
        "vesktop"
        "obs"
        "orbstack"
        "openvpn-connect"
        "herdrm"
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

    # nix-darwin runs `brew bundle` via `sudo --user … --set-home env`, which
    # strips XDG_CONFIG_HOME, so brew reads trust state from `${HOME}/.homebrew/trust.json`.
    # Keep that file (and the XDG one used by interactive shells) in sync.
    system.activationScripts.extraActivation.text = mkAfter ''
      ${pkgs.python3}/bin/python3 - <<'PY'
      import json
      import os
      import pwd

      home = "${userHome}"
      user = "${user}"
      uid = pwd.getpwnam(user).pw_uid
      gid = pwd.getpwnam(user).pw_gid
      rel_paths = [
        os.path.join(".homebrew", "trust.json"),
        os.path.join(".config", "homebrew", "trust.json"),
      ]
      entry = "owo-network/brew"

      for rel in rel_paths:
        path = os.path.join(home, rel)
        os.makedirs(os.path.dirname(path), exist_ok=True)
        data = {"trustedtaps": []}
        try:
            with open(path) as fh:
                data = json.load(fh)
        except Exception:
            pass
        data.setdefault("trustedtaps", [])
        if entry not in data["trustedtaps"]:
            data["trustedtaps"].append(entry)
        with open(path, "w") as fh:
            json.dump(data, fh, indent=2)
            fh.write("\n")
        try:
            os.chmod(path, 0o600)
            os.chown(path, uid, gid)
        except OSError:
            # Not running as root (e.g. standalone activation); brew will
            # still read the file, it just may not be able to rewrite it.
            pass
      PY
    '';
  };
}
