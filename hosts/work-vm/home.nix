# Home Manager for the work VM: the shared headless setup plus work git.
{ ... }:
{
  imports = [ ../../modules/nixos/home/default.nix ];

  # Everything in this machine is work, so one git identity applies to all
  # repos. This repo is public, so the identity lives in a file created inside
  # the VM (see hosts/work-vm/README.md) instead of here.
  programs.git.includes = [ { path = "~/.config/git/work-identity"; } ];
}
