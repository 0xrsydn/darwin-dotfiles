{ config, pkgs, lib, ... }: {
  home.stateVersion = "24.05";

  imports = [
    ./programs/helix.nix
    ./programs/neovim.nix
    ./shell/tmux.nix
    ./devtools/ai-tools.nix
    ./devtools/languages.nix
    ./devtools/default.nix
    ./secrets.nix
  ];

  programs.git.enable = true;

  home.packages = with pkgs; [ docker docker-compose ];

  rsydn.aiTools = {
    enable = lib.mkDefault true;
    claude.zai.enable = lib.mkDefault true;
  };

  rsydn.devTools = {
    enable = lib.mkDefault true;
    packages = with pkgs; [
      ast-grep
      cloudflared
      ffmpeg
      fzf
      htop
      jetbrains-mono
      jq
      lazydocker
      lazygit
      lorri
      nil
      nixd
      pandoc
      ripgrep
      tmux
      tree
      curl
      vim
      wget
      yq
    ];
  };

  rsydn.languages = {
    enable = lib.mkDefault true;
    # Disable global language tools - use nix develop shells instead
    cargo.enable = false;
    go.enable = false;
    bun.enable = false;
    # Keep uv for MCP server and node for npx/tooling
    uv.enable = true;
    node.enable = true;
  };

  rsydn.secrets = lib.mkIf pkgs.stdenv.hostPlatform.isDarwin {
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
