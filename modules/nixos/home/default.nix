{
  config,
  pkgs,
  lib,
  ...
}:
{
  # Minimal CLI-only Home Manager configuration
  # Used for servers, VMs, and headless systems
  # Desktop configs are handled directly in nixos/desktops/* modules

  imports = [
    ../../home/base.nix # Base CLI tools (git, tmux, etc.)
    ../../home/shell/fish.nix # Shell configuration
    ../../home/shell/nushell.nix # Secondary Nushell setup
  ];

  config.programs.tmux.extraConfig = lib.mkAfter ''
    # Prefer fish for interactive sessions; launch Nushell on demand.
    set -g default-shell "${config.home.profileDirectory}/bin/fish"
    set -g default-command "${config.home.profileDirectory}/bin/fish --login"
    bind-key C-n new-window -n nushell "${config.home.profileDirectory}/bin/nu --login"
  '';
}
