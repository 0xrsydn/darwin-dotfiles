{ pkgs, lib, customPkgs, ... }:

pkgs.mkShell {
  name = "ai-agent";

  packages = with pkgs; [
    # Version control
    git
    jujutsu

    # Code search and navigation
    ripgrep
    ast-grep
    fzf

    # JSON processing
    jq
  ];

  shellHook = ''
    # Add home-manager binaries to PATH (claude-code, codex, etc.)
    if [ -d "$HOME/.nix-profile/bin" ]; then
      export PATH="$HOME/.nix-profile/bin:$PATH"
    fi

    echo "AI Agent development shell loaded"
    echo ""
    echo "Available tools:"
    echo "  jj/git          - Version control"
    echo "  rg/ast-grep     - Code search"
  '';
}
