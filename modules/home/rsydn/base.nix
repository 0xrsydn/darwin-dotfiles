{ pkgs, lib, ... }: {
  imports = [
    ./programs/fastfetch.nix
    ./programs/helix.nix
    ./programs/neovim.nix
    ./shell/tmux.nix
    ./devtools/ai-tools.nix
    ./devtools/languages.nix
    ./devtools/default.nix
    ./secrets.nix
  ];

  config = {
    home.stateVersion = "24.05";

    # XDG Base Directory specification
    # Ensures ~/.config, ~/.local/share, ~/.cache are properly set up
    # Note: User directories (Desktop, Downloads, etc.) are configured in desktop modules
    xdg.enable = true;

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
        jujutsu
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
  };
}
