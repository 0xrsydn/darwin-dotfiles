{ pkgs, llm-agents, ... }:
{
  cf = pkgs.callPackage ./cf.nix { };
  codex = pkgs.callPackage ./codex.nix { inherit llm-agents; };
  pikpak-cli = pkgs.callPackage ./pikpak-cli.nix { };
}
