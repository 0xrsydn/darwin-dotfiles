{
  config,
  pkgs,
  lib,
  ...
}:
let
  inherit (lib) mkIf mkOption types;
  cfg = config.rsydn.systemPackages;
in
{
  options.rsydn.systemPackages = {
    enable = mkOption {
      type = types.bool;
      default = true;
      description = "Enable system-wide development packages.";
    };

    packages = mkOption {
      type = types.listOf types.package;
      default = with pkgs; [ tailscale ];
      description = "System packages that must be available globally across macOS.";
    };
  };

  config = mkIf cfg.enable { environment.systemPackages = cfg.packages; };
}
