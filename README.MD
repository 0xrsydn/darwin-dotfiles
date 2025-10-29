# My Nix-Darwin Dotfiles

My current nix dotfiles to managing package and customize (tweak) my macOS environment.

So far, the dotfiles only used for my macOS configuration, maybe in the future I will add my NixOS VM setup, including both dev and prod environments in the future.

## Core System

- OS: macOS (nix-darwin)
- Shell: nushell with starship prompt
- Terminal: ghostty with dracula theme
- Package Management: mix of nix and homebrew 

## Developer Tools

- IDE: neovim (lazyvim bundle) & Helix
- Containers: docker, lazydocker, orbstack
- CLI utils: fzf, ripgrep, ast-grep, jq, yq, pandoc, ffmpeg, tree, htop
- Tmux with dracula theme (plugins: cpu-usage, battery, network-bandwidth monitoring)
- Hybrid approach of globally installed programming language tooling and specific programming language tooling using `nix develop` (still tweaking to see whats the best)

## AI Tools

- CLI-based tools: codex, crush, opencode, claude code
- Custom z.ai gateway wrapper for claude code
- Secret management with SOPS-nix

## Todo List
- [] Scale to NixOS desktop & VM dotfiles too
- [] Easier setup for new machines or my another devices
- [] Configure best development environment setup for me
- [] Stop tweaking and finalize the dotfiles lol
