{
  config,
  lib,
  pkgs,
  inputs,
  ...
}:
let
  inherit (lib)
    mkEnableOption
    mkOption
    types
    mkIf
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
            default = "glm-5";
            description = "Model identifier passed via ANTHROPIC_DEFAULT_OPUS_MODEL.";
          };
          sonnetModel = mkOption {
            type = types.str;
            default = "glm-5";
            description = "Model identifier passed via ANTHROPIC_DEFAULT_SONNET_MODEL.";
          };
          haikuModel = mkOption {
            type = types.str;
            default = "glm-5";
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
        opusModel = "glm-5";
        sonnetModel = "glm-5";
        haikuModel = "glm-5";
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
    ]
    ++ zaiWrapperPackages
    ++ kimiWrapperPackages
    ++ cfg.extraPackages;
  };
}
