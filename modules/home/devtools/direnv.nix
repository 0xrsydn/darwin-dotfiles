{ config, lib, ... }:
let
  inherit (lib) mkOption types mkIf;
  cfg = config.rsydn.direnv;
in
{
  options.rsydn.direnv = {
    enable = mkOption {
      type = types.bool;
      default = false;
      description = "Enable direnv with nix-direnv for automatic devshell activation.";
    };
    silent = mkOption {
      type = types.bool;
      default = true;
      description = "Suppress direnv loading messages.";
    };
  };

  config = mkIf cfg.enable {
    programs.direnv = {
      enable = true;
      enableNushellIntegration = true;
      nix-direnv.enable = true;
      silent = cfg.silent;
    };
  };
}
