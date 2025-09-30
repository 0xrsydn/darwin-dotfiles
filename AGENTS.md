# Repository Guidelines

## Project Structure & Module Organization
- `flake.nix` / `flake.lock`: entry point for nix-darwin + Home Manager; defines overlays and the `macbook-pro` host.
- `modules/darwin/`: machine-level options (`system.nix`, `homebrew.nix`, `devtools.nix`). Extend these for hardware or OS-wide services only.
- `modules/home/rsydn/`: Home Manager profile composed of `programs/`, `shell/`, and `devtools/`. User-level bundles belong here, including AI tooling.
- `.cache/`: local build cache. Keep it out of Git.

## Build, Test, and Development Commands
- `nix develop`: enter the flake’s dev shell (bundles `git`, `nixfmt-classic`, etc.).
- `nix fmt`: format all Nix sources using the flake’s formatter output.
- `XDG_CACHE_HOME=$PWD/.cache nix flake check`: type-checks modules, overlays, and packages without polluting global caches.
- `darwin-rebuild --dry-run --flake .#macbook-pro`: smoke-test activation scripts.
- `darwin-rebuild switch --flake .#macbook-pro`: apply the configuration once validation passes.

## Coding Style & Naming Conventions
- Nix code: two-space indent, trailing commas, lower-kebab filenames (e.g., `shell/nushell.nix`).
- Custom options live under the `rsydn.*` namespace; keep logical groupings (`rsydn.aiTools`, `rsydn.devTools`).
- Run `nix fmt` before committing; avoid manual formatting tweaks that fight the formatter.

## Testing Guidelines
- `nix flake check` is mandatory before any PR; treat failures as regressions.
- For substantial module changes, add `darwin-rebuild --dry-run` output to the PR discussion.
- Pending automated tests should live beside the module they cover; name files after their option namespace (e.g., `rsydn-ai-tools.nix`).

## Commit & Pull Request Guidelines
- Commits: short, imperative subjects (`replace zsh with nushell`), one logical change per commit.
- Include the exact validation commands run (`nix flake check`, dry-run output) in the PR body.
- Reference related issues or TODOs; attach logs/screenshots if they clarify UI-facing changes (e.g., Ghostty themes).

## AI Tooling & Shell Profile
- AI CLIs are toggled via `rsydn.aiTools`; adjust packages and enable flags there rather than invoking installers manually.
- Nushell is the default interactive shell. Any bootstrap scripts must be Nix-managed to avoid PATH drift.
