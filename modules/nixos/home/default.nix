{ config, pkgs, lib, ... }: {
  # Minimal CLI-only Home Manager configuration
  # Used for servers, VMs, and headless systems
  # Desktop configs are handled directly in nixos/desktops/* modules

  imports = [
    ../../home/rsydn/base.nix # Base CLI tools (git, tmux, etc.)
    ../../home/rsydn/shell/fish.nix # Shell configuration
  ];
}
