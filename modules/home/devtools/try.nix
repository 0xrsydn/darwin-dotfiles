{
  config,
  lib,
  pkgs,
  try,
  ...
}:
let
  inherit (lib)
    mkEnableOption
    mkOption
    types
    mkIf
    ;
  cfg = config.rsydn.try;
in
{
  imports = [ try.homeModules.default ];

  options.rsydn.try = {
    enable = mkEnableOption "Try - temporary project directory manager";

    path = mkOption {
      type = types.str;
      default = "~/src/tries";
      description = "Storage directory for try experiment instances.";
    };
  };

  config = mkIf cfg.enable {
    programs.try = {
      enable = true;
      path = cfg.path;
    };
  };
}
