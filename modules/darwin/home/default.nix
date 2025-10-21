{ config, pkgs, lib, ... }: {
  # Import shared cross-platform home configuration
  imports = [
    ../../home/rsydn/base.nix
    ../../home/rsydn/shell/nushell.nix
    ./programs/aerospace
    ./programs/ghostty.nix
  ];
}
