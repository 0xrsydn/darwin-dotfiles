{ pkgs, lib, beads }:

{
  osgrep = pkgs.callPackage ./osgrep.nix { };
  opencode = pkgs.callPackage ./opencode.nix { };
  # Re-export beads from flake input for consistent access
  beads = beads.packages.${pkgs.stdenv.hostPlatform.system}.default;
}
