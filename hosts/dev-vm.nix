{ lib, pkgs, ... }:
{
  networking.hostName = "dev-vm";
  # Set the baseline NixOS release used for stateful data; bump on rebuilds.
  system.stateVersion = lib.mkDefault "24.05";

  # Boot loader configuration for VM
  boot.loader.grub.enable = lib.mkDefault true;
  boot.loader.grub.device = lib.mkDefault "/dev/vda";

  # Root filesystem configuration for VM
  fileSystems."/" = lib.mkDefault {
    device = "/dev/vda1";
    fsType = "ext4";
  };

  environment.systemPackages = with pkgs; [
    # Core utilities
    coreutils
    ast-grep
    ripgrep
    bat
    tree
    zip
    unzip
    jq
    psmisc # provides killall and friends
    gh
    tree-sitter

    # System monitoring & debugging tools
    htop # Process viewer
    iotop # I/O monitoring
    lsof # List open files
    strace # System call tracing
    ltrace # Library call tracing
    gdb # GNU debugger
    tcpdump # Network packet analyzer
    ncdu # Disk usage analyzer
  ];

  services.qemuGuest.enable = true;

  services.openssh.openFirewall = false;

  networking.firewall = {
    allowedTCPPorts = [ ];
    interfaces."tailscale0".allowedTCPPorts = [ 22 ];
  };

  imports = [ ../modules/nixos/virtualization.nix ];
}
