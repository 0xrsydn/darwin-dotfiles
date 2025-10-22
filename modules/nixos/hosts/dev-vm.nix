{ lib, pkgs, ... }: {
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
    coreutils
    ast-grep
    ripgrep
    bat
    tree
    zip
    unzip
    htop
    jq
    psmisc # provides killall and friends
    gh
    tree-sitter
  ];

  imports = [ ../virtualization.nix ];
}
