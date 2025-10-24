{ lib, pkgs, ... }: {
  # Unified desktop configuration for gaming and development
  # Includes both KDE Plasma and Hyprland - switch at login screen

  # Boot configuration with CachyOS LTS kernel
  boot = {
    loader.systemd-boot.enable = true;
    loader.efi.canTouchEfiVariables = true;
    kernelPackages = pkgs.linuxPackages_cachyos-lts;
    # Hardware-specific settings (adjust for your hardware)
    # initrd.availableKernelModules = [ "nvme" "xhci_pci" "ahci" "usb_storage" "sd_mod" ];
  };

  # Hostname
  networking.hostName = "desktop";

  # Root filesystem configuration (REQUIRED - adjust for your hardware)
  # To generate proper config, run: nixos-generate-config --show-hardware-config
  fileSystems."/" = lib.mkDefault {
    device = "/dev/disk/by-label/nixos";
    fsType = "ext4";
  };

  fileSystems."/boot" = lib.mkDefault {
    device = "/dev/disk/by-label/boot";
    fsType = "vfat";
  };

  # Swap configuration (optional, adjust as needed)
  # swapDevices = [ { device = "/dev/disk/by-label/swap"; } ];

  # Desktop environments - both available at login screen
  imports = [
    ../desktops/plasma.nix # For gaming sessions
    ../desktops/hyprland.nix # For development sessions
    # ../desktops/niri.nix # Available for future use
    ../bluetooth.nix
    ../desktop/gaming.nix # Gaming configuration (Steam, Proton, Vulkan, etc.)
  ];

  # GPU drivers (uncomment and adjust for your hardware)
  # For NVIDIA:
  # services.xserver.videoDrivers = [ "nvidia" ];
  # hardware.nvidia = {
  #   modesetting.enable = true;
  #   powerManagement.enable = false;
  #   open = false; # Use proprietary driver
  #   package = config.boot.kernelPackages.nvidiaPackages.stable;
  # };
  #
  # For AMD:
  # services.xserver.videoDrivers = [ "amdgpu" ];
  #
  # For Intel:
  # services.xserver.videoDrivers = [ "modesetting" ];

  # Additional system packages
  environment.systemPackages = with pkgs;
    [
      # Add system-wide tools here if needed
      # Gaming packages are configured in ../desktop/gaming.nix
      # Development tools are better sourced via `nix develop` shells
    ];

  # This value determines the NixOS release compatibility
  system.stateVersion = "24.05";
}
