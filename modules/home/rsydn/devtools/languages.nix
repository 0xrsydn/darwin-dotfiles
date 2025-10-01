{ config, lib, pkgs, ... }:
let
  inherit (lib) mkEnableOption mkOption mkIf types warn unique;
  cfg = config.rsydn.languages;

  hasPkg = name: builtins.hasAttr name pkgs;
  getPkg = name: if hasPkg name then pkgs.${name} else null;

  mkToolOption = { name, defaultPackage, description }:
    mkOption {
      type = types.submodule {
        options = {
          enable = mkOption {
            type = types.bool;
            default = defaultPackage != null;
            description = "Enable ${name} tooling globally.";
          };
          package = mkOption {
            type = types.nullOr types.package;
            default = defaultPackage;
            description =
              "Package derivation to install for ${name}. Set to null to skip.";
          };
        };
      };
      default = {
        enable = defaultPackage != null;
        package = defaultPackage;
      };
      description = description;
    };

  mkToolPackages = specs:
    builtins.concatMap (tool:
      let toolCfg = tool.cfg;
      in if toolCfg.enable then
        if toolCfg.package != null then
          [ toolCfg.package ]
        else
          warn "rsydn.languages.${tool.name}: package is null, skipping" [ ]
      else
        [ ]) specs;

  uvPackage = getPkg "uv";
  goPackage = getPkg "go";
  nodePackage = if builtins.hasAttr "nodejs_20" pkgs then
    pkgs.nodejs_20
  else
    getPkg "nodejs";
  cargoPackage = getPkg "cargo";

  toolSpecs = [
    {
      name = "uv";
      cfg = cfg.uv;
      defaultPackage = uvPackage;
    }
    {
      name = "go";
      cfg = cfg.go;
      defaultPackage = goPackage;
    }
    {
      name = "node";
      cfg = cfg.node;
      defaultPackage = nodePackage;
    }
    {
      name = "cargo";
      cfg = cfg.cargo;
      defaultPackage = cargoPackage;
    }
  ];

  languagePackages = mkToolPackages toolSpecs;

in {
  options.rsydn.languages = {
    enable = mkEnableOption "Language tooling packages for everyday workflows";

    uv = mkToolOption {
      name = "uv";
      defaultPackage = uvPackage;
      description = "Python package installer and virtualenv manager.";
    };

    go = mkToolOption {
      name = "Go";
      defaultPackage = goPackage;
      description = "Go compiler and GOPATH toolchain.";
    };

    node = mkToolOption {
      name = "Node.js";
      defaultPackage = nodePackage;
      description = "Node.js runtime for CLI tooling.";
    };

    cargo = mkToolOption {
      name = "Cargo";
      defaultPackage = cargoPackage;
      description = "Rust package manager and toolchain.";
    };

    extraPackages = mkOption {
      type = types.listOf types.package;
      default = [ ];
      description = "Additional language tooling packages to install globally.";
    };
  };

  config = mkIf cfg.enable {
    home.packages = unique (languagePackages ++ cfg.extraPackages);
  };
}
