{ pkgs, ... }:
{
  # Gaming user configuration (for KDE Plasma)

  imports = [
    # Base CLI tools
    ../../home/rsydn/base.nix

    # Desktop base
    ../../home/rsydn/desktop/base.nix
    ../../home/rsydn/desktop/apps/browsers.nix
  ];

  # Gaming-specific user packages
  home.packages = with pkgs; [
    # Communication
    # discord
    # teamspeak_client

    # Streaming/Recording
    # obs-studio

    # Media
    # spotify
  ];

  # KDE-specific settings (optional)
  # programs.plasma = {
  #   enable = true;
  #   workspace.theme = "breeze-dark";
  # };
}
