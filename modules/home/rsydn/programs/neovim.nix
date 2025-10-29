{ pkgs, ... }: {
  programs.neovim = {
    enable = true;
    viAlias = true;
    vimAlias = true;
    vimdiffAlias = true;

    withNodeJs = true;
    withPython3 = true;
    withRuby = true;

    plugins = with pkgs.vimPlugins; [
      # Native extensions that need building
      telescope-fzf-native-nvim
      blink-cmp # Pre-built with Rust backend for fast fuzzy matching
    ];

    extraPackages = with pkgs; [
      # LSP Servers
      lua-language-server
      nil # Nix LSP
      pyright
      nodePackages.typescript-language-server
      rust-analyzer
      gopls
      clang-tools # provides clangd

      # Formatters
      stylua # Lua
      nixfmt-classic # Nix (matches your fmt command)
      ruff # Python (formatter + linter)
      prettierd # JS/TS/JSON/YAML/Markdown
      rustfmt # Rust
      gofumpt # Go (stricter than gofmt)
      shfmt # Shell scripts

      # Linters
      nodePackages.eslint # JavaScript/TypeScript
      shellcheck # Shell scripts

      # Tools
      ripgrep
      fd
      git
      ast-grep

      # Additional tools for LazyVim features
      tree-sitter # Required for treesitter parser compilation
      imagemagick # Image conversion for snacks.nvim
      ghostscript # PDF rendering support
      tectonic # LaTeX math rendering
      luarocks # Lua package manager for plugins
      nodePackages.mermaid-cli # Mermaid diagram rendering
    ];
  };

  # Symlink LazyVim config to ~/.config/nvim
  xdg.configFile."nvim" = {
    source = ./nvim;
    recursive = true;
  };
}
