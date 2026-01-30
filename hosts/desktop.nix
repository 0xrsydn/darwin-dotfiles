{ lib, pkgs, ... }:
let
  hardwareConfigPath =
    builtins.toString ./. + "/../modules/nixos/desktops/hardware-configuration.nix";
  hardwareModule =
    if builtins.pathExists hardwareConfigPath then import hardwareConfigPath else (_: { });
in
{
  # Unified desktop configuration for gaming and development
  # Includes both KDE Plasma and Hyprland - switch at login screen

  # Import hardware and desktop configurations
  imports = [
    # Hardware
    hardwareModule

    # Audio & Graphics
    ../modules/nixos/audio.nix
    ../modules/nixos/graphics.nix

    # Desktop Environments
    ../modules/nixos/desktops/plasma.nix # KDE Plasma (for gaming)
    ../modules/nixos/desktops/hyprland # Hyprland (for development)

    # Desktop Apps & Theme
    ../modules/nixos/desktops/apps/browsers.nix
    ../modules/nixos/desktops/apps/terminals.nix
    ../modules/nixos/desktops/themes/catppuccin.nix # Or use themes/default.nix for Adwaita

    # Gaming & Features
    ../modules/nixos/desktops/gaming.nix
    ../modules/nixos/bluetooth.nix
  ];

  # Boot configuration with CachyOS LTS kernel
  boot = {
    loader.systemd-boot.enable = true;
    loader.efi.canTouchEfiVariables = true;
    kernelPackages = pkgs.linuxPackages_cachyos-lts;
  };

  # Hostname
  networking.hostName = "desktop";

  # This value determines the NixOS release compatibility
  system.stateVersion = "24.05";
}
