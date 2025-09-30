{ config, lib, pkgs, inputs, ... }:
let
  inherit (lib) mkEnableOption mkOption types mkIf concatMap unique warn;
  cfg = config.rsydn.aiTools;

  nodePackages = if builtins.hasAttr "nodePackages_latest" pkgs then
    pkgs.nodePackages_latest
  else if builtins.hasAttr "nodePackages" pkgs then
    pkgs.nodePackages
  else
    { };

  hasNodePackage = name: builtins.hasAttr name nodePackages;
  getNodePackage = name:
    if hasNodePackage name then nodePackages.${name} else null;

  choosePackage = packages:
    let filtered = lib.filter (pkg: pkg != null) packages;
    in if filtered == [ ] then null else lib.head filtered;

  codexDefault = choosePackage [ (getNodePackage "@openai/codex") ];

  crushFromInput = if builtins.hasAttr "nix-ai-tools" inputs then
    let
      pkgSet = inputs."nix-ai-tools".packages or { };
      system = pkgs.stdenv.hostPlatform.system;
    in if builtins.hasAttr system pkgSet then
      let systemPackages = builtins.getAttr system pkgSet;
      in if builtins.hasAttr "crush" systemPackages then
        builtins.getAttr "crush" systemPackages
      else
        null
    else
      null
  else
    null;

  crushDefault =
    choosePackage [ crushFromInput (getNodePackage "@charmland/crush") ];

  opencodeDefault = choosePackage [ (getNodePackage "opencode-ai") ];

  claudeDefault =
    choosePackage [ (getNodePackage "@anthropic-ai/claude-code") ];

  toolOption = { name, description, defaultPackage }:
    mkOption {
      type = types.submodule {
        options = {
          enable = mkOption {
            type = types.bool;
            default = true;
            description = "Enable the ${name} CLI.";
          };
          package = mkOption {
            type = types.nullOr types.package;
            default = defaultPackage;
            description =
              "Package providing ${name}. Set to null to skip installation.";
          };
        };
      };
      default = {
        enable = true;
        package = defaultPackage;
      };
      description = description;
    };

  gatherToolPackages = tools:
    concatMap (tool:
      let
        name = tool.name;
        cfgTool = tool.cfg;
      in if cfgTool.enable then
        if cfgTool.package != null then
          [ cfgTool.package ]
        else
          warn "rsydn.aiTools.${name}: package is null, skipping install" [ ]
      else
        [ ]) tools;

  toolPackages = gatherToolPackages [
    {
      name = "codex";
      cfg = cfg.codex;
    }
    {
      name = "crush";
      cfg = cfg.crush;
    }
    {
      name = "opencode";
      cfg = cfg.opencode;
    }
    {
      name = "claude";
      cfg = cfg.claude;
    }
  ];

in {
  options.rsydn.aiTools = {
    enable = mkEnableOption "AI-oriented command line tooling";

    codex = toolOption {
      name = "Codex";
      description = "OpenAI Codex CLI (npm @openai/codex).";
      defaultPackage = codexDefault;
    };

    crush = toolOption {
      name = "Crush";
      description = "Charmbracelet Crush CLI for natural language shell.";
      defaultPackage = crushDefault;
    };

    opencode = toolOption {
      name = "OpenCode";
      description = "OpenCode AI collaborative CLI.";
      defaultPackage = opencodeDefault;
    };

    claude = toolOption {
      name = "Claude Code";
      description = "Anthropic Claude Code CLI assistant.";
      defaultPackage = claudeDefault;
    };

    extraPackages = mkOption {
      type = types.listOf types.package;
      default = [ ];
      description =
        "Additional AI tooling packages to add alongside the defaults.";
    };
  };

  config = mkIf cfg.enable {
    home.packages = unique (toolPackages ++ cfg.extraPackages);
  };
}
