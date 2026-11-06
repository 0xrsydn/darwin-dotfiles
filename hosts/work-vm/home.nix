# Home Manager for the work VM: the shared headless setup plus work git.
{ pkgs, ... }:
let
  # OrbStack points BROWSER at its bridge to the Mac, which an isolated
  # machine does not have ("dial: no such file or directory"). Print links
  # instead, to open on the Mac: work-browser for company sites.
  printUrl = pkgs.writeShellScriptBin "print-url" ''
    for url in "$@"; do
      printf 'Open on the Mac (work-browser for company sites):\n  %s\n' "$url" >&2
    done
  '';
in
{
  imports = [ ../../modules/nixos/home/default.nix ];

  # Everything in this machine is work, so one git identity applies to all
  # repos. This repo is public, so the identity lives in a file created inside
  # the VM (see hosts/work-vm/README.md) instead of here.
  programs.git.includes = [ { path = "~/.config/git/work-identity"; } ];

  home.packages = [ printUrl ];
  home.sessionVariables.BROWSER = "print-url";
}
