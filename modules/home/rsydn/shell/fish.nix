{ config, pkgs, lib, ... }: {
  programs.fish = {
    enable = true;
    interactiveShellInit = ''
      set -g fish_greeting ""
      set -gx EDITOR nvim
      set -gx VISUAL nvim
    '';
  };

  # Ensure fish is available for login shells on Linux hosts.
  home.packages = lib.mkAfter [ pkgs.fish ];
}
