{ pkgs, ... }: {
  programs.neovim = {
    enable = true;
    viAlias = true;
    vimAlias = true;
    vimdiffAlias = true;

    withNodeJs = true;
    withPython3 = true;
    withRuby = true;

    extraPackages = with pkgs; [
      # LSP servers
      lua-language-server
      nil

      # Formatters
      stylua
      nixfmt

      # Tools
      ripgrep
      fd
      git
      ast-grep
    ];
  };

  # Symlink LazyVim config to ~/.config/nvim
  xdg.configFile."nvim" = {
    source = ./nvim;
    recursive = true;
  };
}
