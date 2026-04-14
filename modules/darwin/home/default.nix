{
  config,
  pkgs,
  lib,
  ...
}:
{
  # Import shared cross-platform home configuration
  imports = [
    ../../home/base.nix
    ../../home/shell/nushell.nix
    ./programs/aerospace
    ./programs/kitty.nix
  ];

  # Darwin-specific secrets configuration.
  # Materialize the whole encrypted env map once, then let Nushell load it.
  rsydn.secrets = {
    enable = lib.mkDefault true;
    defaultSopsFile = ../../../secrets/global-env.sops.yaml;
    secrets = {
      "global-env" = {
        format = "yaml";
        key = "";
        path = "${config.xdg.configHome}/secrets/global-env.yaml";
      };
    };
  };
}
