{ pkgs, ... }:
{
  # Example gaming desktop configuration
  # Copy and modify for your actual hardware

  # Boot configuration
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  # Hostname
  networking.hostName = "gaming-rig";

  # Import KDE Plasma for gaming
  imports = [ ../desktops/plasma.nix ];

  # Gaming-specific settings
  programs.steam = {
    enable = true;
    remotePlay.openFirewall = true;
    dedicatedServer.openFirewall = true;
  };

  # GameMode for performance optimization
  programs.gamemode.enable = true;

  # GPU drivers (example: NVIDIA)
  # services.xserver.videoDrivers = [ "nvidia" ];
  # hardware.nvidia = {
  #   modesetting.enable = true;
  #   powerManagement.enable = false;
  #   open = false;
  #   package = config.boot.kernelPackages.nvidiaPackages.stable;
  # };

  # Gaming packages
  environment.systemPackages = with pkgs; [
    # Launchers
    lutris
    heroic
    # bottles

    # Tools
    mangohud # FPS overlay
    # gamescope # Gaming compositor
    # protonup-qt # Proton version manager

    # Communication
    discord
  ];

  # This value determines the NixOS release compatibility
  system.stateVersion = "24.05";
}
