{ pkgs, lib, customPkgs, ... }:

let
  # Get Beads package from custom packages
  beadsPkg = customPkgs.beads;

  # Helper script to show Beads project status
  beadsStatus = pkgs.writeShellScriptBin "beads-status" ''
    if [ ! -d ".beads" ]; then
      echo "Not a Beads project (no .beads directory found)"
      exit 1
    fi

    echo "=== Beads Project Status ==="
    echo ""
    echo "Ready tasks:"
    ${beadsPkg}/bin/bd ready --json | ${pkgs.jq}/bin/jq -r '.[] | "  - [\(.id)] \(.title) (\(.type))"'
    echo ""
    echo "In Progress:"
    ${beadsPkg}/bin/bd list --status in-progress --json | ${pkgs.jq}/bin/jq -r '.[] | "  - [\(.id)] \(.title)"'
    echo ""
    echo "For full details, run: bd list --json | jq"
  '';

  # Helper script to generate full project context for AI agents
  beadsContext = pkgs.writeShellScriptBin "beads-context" ''
    if [ ! -d ".beads" ]; then
      echo "Not a Beads project (no .beads directory found)"
      exit 1
    fi

    echo "=== Beads Project Context ==="
    echo ""
    echo "All issues:"
    ${beadsPkg}/bin/bd list --json | ${pkgs.jq}/bin/jq '.'
    echo ""
    echo "Dependency tree (first ready task):"
    ready_id=$(${beadsPkg}/bin/bd ready --json | ${pkgs.jq}/bin/jq -r '.[0].id // empty')
    if [ -n "$ready_id" ]; then
      ${beadsPkg}/bin/bd dep tree "$ready_id"
    else
      echo "No ready tasks"
    fi
  '';

in pkgs.mkShell {
  name = "ai-agent";

  packages = with pkgs; [
    # Custom packages
    customPkgs.beads
    customPkgs.osgrep

    # Version control
    git
    jujutsu

    # Code search and navigation
    ripgrep
    ast-grep
    fzf

    # JSON processing
    jq

    # Helper scripts
    beadsStatus
    beadsContext
  ];

  shellHook = ''
    # Add home-manager binaries to PATH (claude-code, codex, etc.)
    if [ -d "$HOME/.nix-profile/bin" ]; then
      export PATH="$HOME/.nix-profile/bin:$PATH"
    fi

    echo "AI Agent development shell loaded"
    echo ""
    echo "Available tools:"
    echo "  bd              - Beads CLI (issue tracker)"
    echo "  beads-status    - Show project status summary"
    echo "  beads-context   - Generate full context for AI"
    echo "  osgrep          - Semantic code search"
    echo "  jj/git          - Version control"
    echo "  rg/ast-grep     - Code search"
    echo ""
    echo "Quick start:"
    echo "  bd init         - Initialize Beads in current project"
    echo "  bd create       - Create new issue"
    echo "  bd ready        - Show ready tasks"
    echo "  bd --help       - Full command reference"
    echo ""
    echo "Nushell helpers (if in nushell):"
    echo "  bd-init         - Safe init with git checks"
    echo "  bd-ready        - View ready tasks (structured)"
    echo "  bd-sync         - Sync database with git"
  '';
}
