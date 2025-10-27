{ config, pkgs, lib, ... }: {
  # Import shared cross-platform home configuration
  imports = [
    ../../home/rsydn/base.nix
    ../../home/rsydn/shell/nushell.nix
    ./programs/aerospace
    ./programs/ghostty.nix
  ];

  # Darwin-specific secrets configuration
  rsydn.secrets = {
    enable = lib.mkDefault true;
    defaultSopsFile = ../../../secrets/local-ai-tokens.sops.yaml;
    secrets = {
      "openai-api-key" = {
        format = "yaml";
        key = "OPENAI_API_KEY";
      };

      "openrouter-api-key" = {
        format = "yaml";
        key = "OPENROUTER_API_KEY";
      };

      "zai-api-key" = {
        format = "yaml";
        key = "ZAI_API_KEY";
      };

      "moonshot-api-key" = {
        format = "yaml";
        key = "MOONSHOT_API_KEY";
      };

      "anthropic-api-key" = {
        format = "yaml";
        key = "ANTHROPIC_API_KEY";
      };

      "exa-api-key" = {
        format = "yaml";
        key = "EXA_API_KEY";
      };

      "fal-api-key" = {
        format = "yaml";
        key = "FAL_API_KEY";
      };

      "groq-api-key" = {
        format = "yaml";
        key = "GROQ_API_KEY";
      };

      "firecrawl-api-key" = {
        format = "yaml";
        key = "FIRECRAWL_API_KEY";
      };
    };
  };
}
