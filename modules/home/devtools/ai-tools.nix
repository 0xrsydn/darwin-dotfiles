{ config, lib, pkgs, inputs, ... }:
let
  inherit (lib) mkEnableOption mkOption types mkIf escapeShellArg;
  cfg = config.rsydn.aiTools;
  system = pkgs.stdenv.hostPlatform.system;

  # Latest llm-agents for most tools
  llmPkgs = inputs.llm-agents.packages.${system};
  # Pinned llm-agents for Claude Code 2.0.64
  llmPkgsPinned = inputs.llm-agents-pinned.packages.${system};

  # Z.AI Gateway wrapper for Claude Code
  zaiWrapperPackages = let zaiCfg = cfg.zai;
  in if zaiCfg.enable then
    let
      claudeExe = lib.getExe llmPkgsPinned.claude-code;
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
    [ ];

in {
  options.rsydn.aiTools = {
    enable = mkEnableOption "AI CLI tools from llm-agents.nix";

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
            default = "glm-4.7";
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
        model = "glm-4.7";
        tokenEnvVar = "ZAI_API_KEY";
      };
      description =
        "Configuration for the Claude wrapper that targets the Z.AI gateway.";
    };

    extraPackages = mkOption {
      type = types.listOf types.package;
      default = [ ];
      description =
        "Additional AI tooling packages to add alongside the defaults.";
    };
  };

  config = mkIf cfg.enable {
    home.packages = [
      llmPkgsPinned.claude-code # pinned to 2.0.64
      llmPkgs.opencode # latest
      llmPkgs.crush # latest
      llmPkgs.ccstatusline # latest
      llmPkgs.ccusage # latest
      llmPkgs.codex
    ] ++ zaiWrapperPackages ++ cfg.extraPackages;
  };
}
