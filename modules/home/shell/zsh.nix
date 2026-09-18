{ config, ... }:
{
  programs.zsh = {
    enable = true;
    enableCompletion = true;
    dotDir = config.home.homeDirectory;

    oh-my-zsh = {
      enable = true;
      plugins = [
        "git"
        "sudo"
      ];
    };

    shellAliases.ssh = "kitten ssh";

    profileExtra = ''
      if [[ -x /opt/homebrew/bin/brew ]]; then
        eval "$(/opt/homebrew/bin/brew shellenv)"
      elif [[ -x /usr/local/bin/brew ]]; then
        eval "$(/usr/local/bin/brew shellenv)"
      fi

      [[ -r "$HOME/.orbstack/shell/init.zsh" ]] && source "$HOME/.orbstack/shell/init.zsh"
    '';

    initContent = ''
      typeset -U path PATH
      path=(
        "$HOME/.cache/.bun/bin"
        "$HOME/.local/bin"
        $path
        "$HOME/.lmstudio/bin"
      )
      export PATH

      _load_global_secrets() {
        local secret_dir="''${XDG_CONFIG_HOME:-$HOME/.config}/secrets/global-env"
        local secret_file name value

        [[ -d "$secret_dir" ]] || return 0

        # `-.` matches plain files and symlinks to plain files.
        # sops-nix links each runtime secret into this directory.
        for secret_file in "$secret_dir"/*(N-.); do
          name="''${secret_file:t}"
          [[ "$name" =~ '^[A-Za-z_][A-Za-z0-9_]*$' ]] || continue
          value="$(<"$secret_file")"
          export "$name=$value"
        done
      }

      _load_global_secrets
      unfunction _load_global_secrets

      dotfiles-qa() (
        local dotfiles_dir="${config.home.homeDirectory}/Development/dotfiles"

        print -P "%F{green}Running dotfiles QA validation...%f"
        cd "$dotfiles_dir" || return 1

        print -P "%F{blue}1. Formatting Nix files...%f"
        nix fmt . || {
          print -P "%F{red}Formatting failed.%f"
          return 1
        }

        print -P "%F{blue}2. Running flake checks...%f"
        XDG_CACHE_HOME="$dotfiles_dir/.cache" nix flake check || {
          print -P "%F{red}Flake checks failed.%f"
          return 1
        }

        print -P "%F{blue}3. Building the Darwin configuration...%f"
        darwin-rebuild build --flake "$dotfiles_dir#macbook-pro" || {
          print -P "%F{red}Darwin build failed.%f"
          return 1
        }

        print -P "%F{green}Core QA checks passed.%f"
      )

      bd-init() {
        if [[ ! -d .git && ! -f .git ]]; then
          print -P "%F{red}Error: not in a Git repository.%f"
          print "Initialize one with: git init"
          return 1
        fi

        if [[ -e .beads ]]; then
          print -P "%F{yellow}Beads is already initialized in this project.%f"
          return 0
        fi

        bd init || return
        print -P "%F{green}Beads initialized.%f"
        print "Next steps:"
        print '  bd create --title "Your task" --type feature'
        print "  bd ready"
      }

      bd-ready() {
        if [[ ! -e .beads ]]; then
          print -P "%F{red}Not a Beads project. Run bd-init first.%f"
          return 1
        fi

        local ready_tasks
        ready_tasks="$(bd ready --json)" || return

        if [[ "$(print -r -- "$ready_tasks" | jq 'length')" == 0 ]]; then
          print -P "%F{yellow}No ready tasks.%f"
          return 0
        fi

        print -P "%F{green}Ready tasks:%f"
        print -r -- "$ready_tasks" | jq -r '
          .[] |
          "[\(.id)] \(.title)\n  Type: \(.type) | Priority: \(.priority) | Status: \(.status)" +
          (if ((.description // "") | length) > 0 then "\n  \(.description)" else "" end) +
          "\n"
        '
      }

      bd-sync() {
        if [[ ! -e .beads ]]; then
          print -P "%F{red}Not a Beads project.%f"
          return 1
        fi

        print -P "%F{blue}Syncing Beads database...%f"
        bd sync || return
        print -P "%F{green}Sync complete.%f"
      }
    '';
  };
}
