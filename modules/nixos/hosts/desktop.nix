{ lib, pkgs, ... }:
let
  hardwareConfigPath = builtins.toString ./.
    + "/../desktops/hardware-configuration.nix";
  hardwareModule = if builtins.pathExists hardwareConfigPath then
    import hardwareConfigPath
  else
    (_: { });
in {
  # Unified desktop configuration for gaming and development
  # Includes both KDE Plasma and Hyprland - switch at login screen

  # Import hardware and desktop configurations
  imports = [
    # Hardware
    hardwareModule

    # Audio & Graphics
    ../audio.nix
    ../graphics.nix

    # Desktop Environments
    ../desktops/plasma.nix # KDE Plasma (for gaming)
    ../desktops/hyprland # Hyprland (for development)

    # Desktop Apps & Theme
    ../desktops/apps/browsers.nix
    ../desktops/apps/terminals.nix
    ../desktops/themes/catppuccin.nix # Or use themes/default.nix for Adwaita

    # Gaming & Features
    ../desktops/gaming.nix
    ../bluetooth.nix
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
