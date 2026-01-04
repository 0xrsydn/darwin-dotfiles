{ pkgs, lib, llm-agents }:

let
  system = pkgs.stdenv.hostPlatform.system;
  llmPkgs = llm-agents.packages.${system};
in {
  opencode = llmPkgs.opencode;
}
