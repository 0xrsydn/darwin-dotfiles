{
  config,
  lib,
  pkgs,
  ...
}:
let
  inherit (lib) mkOption types mkIf;
  cfg = config.rsydn.devTools;
in
{
  options.rsydn.devTools = {
    enable = mkOption {
      type = types.bool;
      default = false;
      description = "Enable per-user development tooling packages.";
    };
    packages = mkOption {
      type = types.listOf types.package;
      default = [ ];
      description = "Extra user-scoped packages to install.";
    };
  };

  config = mkIf cfg.enable { home.packages = cfg.packages; };
}
