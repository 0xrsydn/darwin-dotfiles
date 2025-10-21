{ config, pkgs, lib, ... }: {
  # Import shared cross-platform home configuration
  imports = [
    ../../home/rsydn/base.nix
    ./programs/aerospace
    ./programs/ghostty.nix
  ];
}
