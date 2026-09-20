{ pkgs, llm-agents, ... }:
{
  cf = pkgs.callPackage ./cf.nix { };
  pi = pkgs.callPackage ./pi.nix { inherit llm-agents; };
  pikpak-cli = pkgs.callPackage ./pikpak-cli.nix { };
}
