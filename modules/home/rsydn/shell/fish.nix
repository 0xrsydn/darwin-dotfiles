{ config, pkgs, lib, ... }: {
  imports = [ ./oh-my-posh ];

  programs.fish = {
    enable = true;
    interactiveShellInit = ''
      set -g fish_greeting ""
      set -gx EDITOR nvim
      set -gx VISUAL nvim
    '';
  };

  programs.oh-my-posh.enableFishIntegration = lib.mkDefault true;

  # Ensure fish is available for login shells on Linux hosts.
  home.packages = lib.mkAfter [ pkgs.fish ];
}
