{
  pkgs,
  lib,
  llm-agents,
  ...
}:
let
  # llm-agents does not publish every platform (it dropped x86_64-darwin), so
  # expose codex only where the input provides it.
  hasCodex = builtins.hasAttr pkgs.stdenv.hostPlatform.system llm-agents.packages;
in
{
  cf = pkgs.callPackage ./cf.nix { };
  pikpak-cli = pkgs.callPackage ./pikpak-cli.nix { };
}
// lib.optionalAttrs hasCodex {
  codex = pkgs.callPackage ./codex.nix { inherit llm-agents; };
}
