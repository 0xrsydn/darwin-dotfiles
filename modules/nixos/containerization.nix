{ config, lib, pkgs, ... }:
let
  inherit (lib) mkEnableOption mkOption mkIf types mkMerge mkAfter optionals;
  cfg = config.rsydn.containerization;
in {
  options.rsydn.containerization = {
    docker = {
      enable = mkOption {
        type = types.bool;
        default = true;
        description =
          "Enable the Docker daemon with sane defaults for development.";
      };

      autoPrune = mkOption {
        type = types.submodule {
          options = {
            enable = mkOption {
              type = types.bool;
              default = true;
              description =
                "Automatically prune unused Docker data on a schedule.";
            };
            dates = mkOption {
              type = types.str;
              default = "weekly";
              description =
                "Systemd calendar expression for docker system prune.";
            };
            flags = mkOption {
              type = types.listOf types.str;
              default = [ "--all" "--volumes" ];
              description = "Extra flags passed to docker system prune.";
            };
          };
        };
        default = { };
        description = "Settings for automatic Docker pruning.";
      };
    };

    k3s = {
      enable =
        mkEnableOption "Run a lightweight Kubernetes control plane with k3s.";

      role = mkOption {
        type = types.enum [ "server" "agent" ];
        default = "server";
        description = "Choose whether this node runs as a k3s server or agent.";
      };

      extraFlags = mkOption {
        type = types.listOf types.str;
        default = [ "--write-kubeconfig-mode=0644" ];
        description = "Additional flags to pass to the k3s service.";
      };
    };
  };

  config = mkMerge [
    (mkIf cfg.docker.enable {
      virtualisation.docker = {
        enable = true;
        package = pkgs.docker;
        enableOnBoot = true;
        autoPrune = {
          enable = cfg.docker.autoPrune.enable;
          dates = cfg.docker.autoPrune.dates;
          flags = cfg.docker.autoPrune.flags;
        };
      };
    })

    (mkIf cfg.k3s.enable {
      services.k3s = {
        enable = true;
        role = cfg.k3s.role;
        extraFlags = cfg.k3s.extraFlags;
      };

      networking.firewall.allowedTCPPorts =
        mkAfter (optionals (cfg.k3s.role == "server") [ 6443 ]);
    })
  ];
}
