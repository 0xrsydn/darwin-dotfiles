{ config, pkgs, lib, ... }:
{
  imports = [
    ./programs/helix.nix
    ./shell/zsh.nix
    ./devtools/default.nix
  ];

  rsydn.shell.zsh = {
    enable = true;
    plugins = [];
    extraAfter = ''
      # Source personal secrets
      [ -f ~/.config/zsh/secrets.zsh ] && source ~/.config/zsh/secrets.zsh
      
      # Custom PATH additions
      export PATH="$HOME/.local/bin:$PATH"
      export PATH="$PATH:$HOME/.composer/vendor/bin"
      export PATH="$HOME/.claude/local/bin:$PATH"
      export PATH="$HOME/go/bin:$PATH"
      export PATH="/usr/local/texlive/2024/bin/universal-darwin:$PATH"
      
      # NVM setup
      export NVM_DIR="$HOME/.nvm"
      [ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
      [ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"
      
      # Bun setup
      export BUN_INSTALL="$HOME/.bun"
      export PATH="$BUN_INSTALL/bin:$PATH"
      
      # pnpm setup
      export PNPM_HOME="$HOME/Library/pnpm"
      case ":$PATH:" in
        *":$PNPM_HOME:"*) ;;
        *) export PATH="$PNPM_HOME:$PATH" ;;
      esac
      
      # LM Studio
      export PATH="$PATH:$HOME/.lmstudio/bin"
      
      # opencode
      export PATH="$HOME/.opencode/bin:$PATH"
      
      # Custom aliases
      alias runopenwebui='DATA_DIR=~/.open-webui uvx --python 3.11 open-webui@latest serve'
      
      # Vi mode
      bindkey -v
      
      # Conda setup (managed by conda init)
      # >>> conda initialize >>>
      __conda_setup="$('/opt/homebrew/Caskroom/miniconda/base/bin/conda' 'shell.zsh' 'hook' 2> /dev/null)"
      if [ $? -eq 0 ]; then
          eval "$__conda_setup"
      else
          if [ -f "/opt/homebrew/Caskroom/miniconda/base/etc/profile.d/conda.sh" ]; then
              . "/opt/homebrew/Caskroom/miniconda/base/etc/profile.d/conda.sh"
          else
              export PATH="/opt/homebrew/Caskroom/miniconda/base/bin:$PATH"
          fi
      fi
      unset __conda_setup
      # <<< conda initialize <<<
    '';
  };

  rsydn.devTools = {
    enable = lib.mkDefault false;
    packages = [];
  };
}
