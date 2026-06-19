{
  config,
  lib,
  pkgs,
  inputs,
  customPkgs,
  ...
}:
let
  inherit (lib)
    mkEnableOption
    mkOption
    types
    mkIf
    mkMerge
    escapeShellArg
    ;
  cfg = config.rsydn.aiTools;
  system = pkgs.stdenv.hostPlatform.system;

  # Latest llm-agents for most tools
  llmPkgs = inputs.llm-agents.packages.${system};
  # Pinned llm-agents for Claude Code 2.0.64
  llmPkgsPinned = inputs.llm-agents-pinned.packages.${system};

  # Z.AI Gateway wrapper for Claude Code
  zaiWrapperPackages =
    let
      zaiCfg = cfg.zai;
    in
    if zaiCfg.enable then
      let
        claudeExe = lib.getExe llmPkgs.claude-code;
        commandName = zaiCfg.commandName;
        baseUrl = zaiCfg.baseUrl;
        opusModel = zaiCfg.opusModel;
        sonnetModel = zaiCfg.sonnetModel;
        haikuModel = zaiCfg.haikuModel;
        tokenEnvVar = zaiCfg.tokenEnvVar;
      in
      [
        (pkgs.writeShellApplication {
          name = commandName;
          text = ''
            if [ -z "''${${tokenEnvVar}:-}" ]; then
              echo "${commandName}: environment variable ${tokenEnvVar} is not set" >&2
              exit 1
            fi

            export ANTHROPIC_BASE_URL=${escapeShellArg baseUrl}
            export ANTHROPIC_AUTH_TOKEN="''${${tokenEnvVar}}"
            export ANTHROPIC_DEFAULT_OPUS_MODEL=${escapeShellArg opusModel}
            export ANTHROPIC_DEFAULT_SONNET_MODEL=${escapeShellArg sonnetModel}
            export ANTHROPIC_DEFAULT_HAIKU_MODEL=${escapeShellArg haikuModel}

            exec ${claudeExe} "$@"
          '';
        })
      ]
    else
      [ ];

  # Kimi Code API wrapper for Claude Code
  kimiWrapperPackages =
    let
      kimiCfg = cfg.kimi;
    in
    if kimiCfg.enable then
      let
        claudeExe = lib.getExe llmPkgs.claude-code;
        commandName = kimiCfg.commandName;
        baseUrl = kimiCfg.baseUrl;
        tokenEnvVar = kimiCfg.tokenEnvVar;
      in
      [
        (pkgs.writeShellApplication {
          name = commandName;
          text = ''
            if [ -z "''${${tokenEnvVar}:-}" ]; then
              echo "${commandName}: environment variable ${tokenEnvVar} is not set" >&2
              exit 1
            fi

            export ANTHROPIC_BASE_URL=${escapeShellArg baseUrl}
            export ANTHROPIC_API_KEY="''${${tokenEnvVar}}"

            exec ${claudeExe} "$@"
          '';
        })
      ]
    else
      [ ];

in
{
  options.rsydn.aiTools = {
    enable = mkEnableOption "AI CLI tools from llm-agents.nix";

    zai = mkOption {
      type = types.submodule {
        options = {
          enable = mkEnableOption "Expose the Z.AI Gateway wrapper command for Claude.";
          commandName = mkOption {
            type = types.str;
            default = "glm";
            description = "Name of the wrapper command that launches Claude via Z.AI.";
          };
          baseUrl = mkOption {
            type = types.str;
            default = "https://api.z.ai/api/anthropic";
            description = "Gateway base URL used for the Anthropic client.";
          };
          opusModel = mkOption {
            type = types.str;
            default = "glm-5.1";
            description = "Model identifier passed via ANTHROPIC_DEFAULT_OPUS_MODEL.";
          };
          sonnetModel = mkOption {
            type = types.str;
            default = "glm-5.1";
            description = "Model identifier passed via ANTHROPIC_DEFAULT_SONNET_MODEL.";
          };
          haikuModel = mkOption {
            type = types.str;
            default = "glm-5.1";
            description = "Model identifier passed via ANTHROPIC_DEFAULT_HAIKU_MODEL.";
          };
          tokenEnvVar = mkOption {
            type = types.str;
            default = "ZAI_API_KEY";
            description = "Environment variable that stores the Z.AI API token.";
          };
        };
      };
      default = {
        enable = false;
        commandName = "glm";
        baseUrl = "https://api.z.ai/api/anthropic";
        opusModel = "glm-5.1";
        sonnetModel = "glm-5.1";
        haikuModel = "glm-5.1";
        tokenEnvVar = "ZAI_API_KEY";
      };
      description = "Configuration for the Claude wrapper that targets the Z.AI gateway.";
    };

    kimi = mkOption {
      type = types.submodule {
        options = {
          enable = mkEnableOption "Expose the Kimi Code API wrapper command for Claude.";
          commandName = mkOption {
            type = types.str;
            default = "kimi";
            description = "Name of the wrapper command that launches Claude via Kimi.";
          };
          baseUrl = mkOption {
            type = types.str;
            default = "https://api.kimi.com/coding/";
            description = "Kimi Code API base URL used for the Anthropic client.";
          };
          tokenEnvVar = mkOption {
            type = types.str;
            default = "KIMI_API_KEY";
            description = "Environment variable that stores the Kimi API token.";
          };
        };
      };
      default = {
        enable = false;
        commandName = "kimi";
        baseUrl = "https://api.kimi.com/coding/";
        tokenEnvVar = "KIMI_API_KEY";
      };
      description = "Configuration for the Claude wrapper that targets the Kimi Code API.";
    };

    piInstructions = mkOption {
      type = types.submodule {
        options = {
          enable = mkEnableOption "Install the global pi AGENTS.md instructions file.";
          source = mkOption {
            type = types.path;
            default = ../../../pi/AGENTS.md;
            description = "Source file for global pi instructions.";
          };
        };
      };
      default = {
        enable = true;
        source = ../../../pi/AGENTS.md;
      };
      description = "Configuration for the global pi instructions file deployment.";
    };

    piExtensions = mkOption {
      type = types.submodule {
        options = {
          enable = mkEnableOption "Install the global pi extensions directory.";
          source = mkOption {
            type = types.path;
            default = ../../../pi/extensions;
            description = "Source directory for the global pi extensions tree.";
          };
        };
      };
      default = {
        enable = true;
        source = ../../../pi/extensions;
      };
      description = "Configuration for the global pi extensions directory deployment.";
    };

    piSkills = mkOption {
      type = types.submodule {
        options = {
          enable = mkEnableOption "Install the global pi skills directory.";
          source = mkOption {
            type = types.path;
            default = ../../../pi/skills;
            description = "Source directory for the global pi skills tree.";
          };
        };
      };
      default = {
        enable = true;
        source = ../../../pi/skills;
      };
      description = "Configuration for the global pi skills directory deployment.";
    };

    piPrompts = mkOption {
      type = types.submodule {
        options = {
          enable = mkEnableOption "Install the global pi prompt templates directory.";
          source = mkOption {
            type = types.path;
            default = ../../../pi/prompts;
            description = "Source directory for the global pi prompt templates tree.";
          };
        };
      };
      default = {
        enable = true;
        source = ../../../pi/prompts;
      };
      description = "Configuration for the global pi prompt templates directory deployment.";
    };

    piThemes = mkOption {
      type = types.submodule {
        options = {
          enable = mkEnableOption "Install the global pi themes directory.";
          source = mkOption {
            type = types.path;
            default = ../../../pi/themes;
            description = "Source directory for the global pi themes tree.";
          };
        };
      };
      default = {
        enable = true;
        source = ../../../pi/themes;
      };
      description = "Configuration for the global pi themes directory deployment.";
    };

    extraPackages = mkOption {
      type = types.listOf types.package;
      default = [ ];
      description = "Additional AI tooling packages to add alongside the defaults.";
    };
  };

  config = mkIf cfg.enable {
    home.packages = [
      llmPkgs.claude-code # latest
      llmPkgs.opencode # latest
      llmPkgs.pi
      llmPkgs.ccstatusline # latest
      llmPkgs.ccusage # latest
      llmPkgs.codex
      llmPkgs.rtk
    ]
    ++ zaiWrapperPackages
    ++ kimiWrapperPackages
    ++ cfg.extraPackages;

    home.activation.installPiFff = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
      if [ -x ${lib.getExe llmPkgs.pi} ]; then
        export PI_SKIP_VERSION_CHECK=1
        export PI_TELEMETRY=0
        export PATH=${pkgs.nodejs}/bin:${pkgs.git}/bin:$PATH

        settings_file="$HOME/.pi/agent/settings.json"
        mkdir -p "$(dirname "$settings_file")"
        ${pkgs.nodejs}/bin/node -e "const fs=require('fs'); const path=process.env.HOME+'/.pi/agent/settings.json'; let settings={}; if (fs.existsSync(path)) settings=JSON.parse(fs.readFileSync(path,'utf8')); settings.theme='dark'; fs.writeFileSync(path, JSON.stringify(settings, null, 2)+String.fromCharCode(10));"

        ${lib.getExe llmPkgs.pi} list | ${pkgs.gnugrep}/bin/grep -q '@ff-labs/pi-fff' || \
          ${lib.getExe llmPkgs.pi} install npm:@ff-labs/pi-fff@0.9.4
        ${lib.getExe llmPkgs.pi} list | ${pkgs.gnugrep}/bin/grep -q '@juicesharp/rpiv-ask-user-question' || \
          ${lib.getExe llmPkgs.pi} install npm:@juicesharp/rpiv-ask-user-question@1.20.0
      fi
    '';

    home.file = mkMerge [
      {
        ".pi/agent/models.json" = {
          source = ../../../pi/models.json;
        };
      }
      (mkIf cfg.piInstructions.enable {
        ".pi/agent/AGENTS.md" = {
          source = cfg.piInstructions.source;
        };
      })
      (mkIf cfg.piExtensions.enable {
        ".pi/agent/extensions" = {
          source = cfg.piExtensions.source;
          recursive = true;
        };
      })
      (mkIf cfg.piSkills.enable {
        ".pi/agent/skills" = {
          source = cfg.piSkills.source;
          recursive = true;
        };
      })
      (mkIf cfg.piPrompts.enable {
        ".pi/agent/prompts" = {
          source = cfg.piPrompts.source;
          recursive = true;
        };
      })
      (mkIf cfg.piThemes.enable {
        ".pi/agent/themes" = {
          source = cfg.piThemes.source;
          recursive = true;
        };
      })
    ];
  };
}
