{ pkgs, ... }: {
  # Example desktop development workstation configuration
  # Copy and modify for your actual hardware

  # Boot configuration (adjust for your system)
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  # Hostname
  networking.hostName = "desktop-dev";

  # Import desktop environment (choose one)
  imports = [
    ../desktops/hyprland.nix
    # ../desktops/plasma.nix
    # ../desktops/niri.nix
  ];

  # Hardware-specific settings (adjust for your hardware)
  # boot.initrd.availableKernelModules = [ "nvme" "xhci_pci" "ahci" "usb_storage" "sd_mod" ];

  # GPU drivers (uncomment if using NVIDIA)
  # services.xserver.videoDrivers = [ "nvidia" ];
  # hardware.nvidia = {
  #   modesetting.enable = true;
  #   open = false; # Use proprietary driver
  # };

  # Optional: Enable bluetooth
  # hardware.bluetooth.enable = true;

  # Development-specific packages
  environment.systemPackages = with pkgs;
    [
      # Add desktop dev tools here
      # docker-compose
      # k9s
    ];

  # This value determines the NixOS release compatibility
  system.stateVersion = "24.05";
}
