{ config, lib, pkgs, inputs, ... }:
let
  inherit (lib)
    mkEnableOption
    mkOption
    types
    mkIf
    concatMap
    unique
    warn
    escapeShellArg;
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

  toolOption =
    { name
    , description
    , defaultPackage
    , extraOptions ? { }
    , extraDefaults ? { }
    }:
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
        } // extraOptions;
      };
      default = {
        enable = true;
        package = defaultPackage;
      } // extraDefaults;
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

  zaiWrapperPackages =
    let
      claudeCfg = cfg.claude;
      zaiCfg = claudeCfg.zai or { enable = false; };
    in if claudeCfg.enable && zaiCfg.enable then
      if claudeCfg.package != null then
        let
          claudeExe = lib.getExe claudeCfg.package;
          commandName = zaiCfg.commandName;
          baseUrl = zaiCfg.baseUrl;
          model = zaiCfg.model;
          tokenEnvVar = zaiCfg.tokenEnvVar;
        in [
          (pkgs.writeShellApplication {
            name = commandName;
            text = ''
              if [ -z "''${${tokenEnvVar}:-}" ]; then
                echo "${commandName}: environment variable ${tokenEnvVar} is not set" >&2
                exit 1
              fi

              export ANTHROPIC_BASE_URL=${escapeShellArg baseUrl}
              export ANTHROPIC_AUTH_TOKEN="''${${tokenEnvVar}}"
              export ANTHROPIC_MODEL=${escapeShellArg model}

              exec ${claudeExe} "$@"
            '';
          })
        ]
      else
        warn "rsydn.aiTools.claude: Z.AI wrapper requested but package is null" [ ]
    else
      [ ];

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
      extraOptions = {
        zai = mkOption {
          type = types.submodule {
            options = {
              enable = mkEnableOption
                "Expose the Z.AI Gateway wrapper command for Claude.";
              commandName = mkOption {
                type = types.str;
                default = "glm";
                description =
                  "Name of the wrapper command that launches Claude via Z.AI.";
              };
              baseUrl = mkOption {
                type = types.str;
                default = "https://api.z.ai/api/anthropic";
                description = "Gateway base URL used for the Anthropic client.";
              };
              model = mkOption {
                type = types.str;
                default = "glm-4.6";
                description = "Model identifier passed via ANTHROPIC_MODEL.";
              };
              tokenEnvVar = mkOption {
                type = types.str;
                default = "ZAI_API_KEY";
                description =
                  "Environment variable that stores the Z.AI API token.";
              };
            };
          };
          default = {
            enable = false;
            commandName = "glm";
            baseUrl = "https://api.z.ai/api/anthropic";
            model = "glm-4.6";
            tokenEnvVar = "ZAI_API_KEY";
          };
          description =
            "Configuration for the Claude wrapper that targets the Z.AI gateway.";
        };
      };
    };

    extraPackages = mkOption {
      type = types.listOf types.package;
      default = [ ];
      description =
        "Additional AI tooling packages to add alongside the defaults.";
    };
  };

  config = mkIf cfg.enable {
    home.packages = unique (toolPackages ++ zaiWrapperPackages ++ cfg.extraPackages);
  };
}
