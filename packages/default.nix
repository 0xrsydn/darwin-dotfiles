{ pkgs, lib, llm-agents }:

let
  system = pkgs.stdenv.hostPlatform.system;
  llmPkgs = llm-agents.packages.${system};
in {
  osgrep = pkgs.callPackage ./osgrep.nix { };
  opencode = llmPkgs.opencode;
  # Source beads from llm-agents.nix
  beads = llmPkgs.beads;
}
