# Repository Guidelines

## Project Structure & Module Organization
- `flake.nix`/`flake.lock` drive the entire nix-darwin + Home Manager configuration; `macbook-pro` is the only declared host.
- `modules/darwin/` contains device-level modules (`system.nix`, `homebrew.nix`, `devtools.nix`). Keep OS services and hardware toggles here.
- `modules/home/rsydn/` provides the Home Manager profile. Subdirectories `programs/`, `shell/`, and `devtools/` house user apps, Nushell/theming, and language/AI bundles.
- Secrets belong under `secrets/*.sops.yaml`; decrypted payloads are emitted into `~/.config/secrets/` at activation. The cached build outputs in `.cache/` stay untracked.

## Build, Test & Development Commands
- `nix develop` — enter the flake dev shell with `git`, `nixfmt-classic`, and Age/SOPS helpers.
- `nix fmt` — format every Nix file via the flake’s formatter; run after edits to modules or overlays.
- `XDG_CACHE_HOME=$PWD/.cache nix flake check` — lint and type-check all modules without touching the global cache.
- `darwin-rebuild --dry-run --flake .#macbook-pro` — validate activation steps and surface breaking changes.
- `darwin-rebuild switch --flake .#macbook-pro` — apply the configuration once checks succeed.

## Coding Style & Naming Conventions
- Nix sources use two-space indents, trailing commas, and lower-kebab filenames (`shell/nushell.nix`).
- Custom options live in the `rsydn.*` namespace (`rsydn.aiTools`, `rsydn.devTools`). Extend existing option sets instead of scattering ad-hoc attributes.
- Prefer declarative package toggles over ad-hoc installers; Nushell, AI CLIs, and prompts are all Home Manager managed.

## Testing Guidelines
- Run `nix flake check` before every PR or local switch; treat failures as blockers.
- Capture key outputs (e.g., `darwin-rebuild --dry-run`) for substantial module changes and share in review threads.
- If you add reusable logic, colocate regression tests beside the module using the `<option-name>.nix` pattern (e.g., `rsydn-ai-tools.nix`).

## Commit & Pull Request Guidelines
- Use short, imperative commit subjects (`add nushell env path hook`); keep each commit scoped to one logical change.
- Document validation steps in the PR body (`nix flake check`, dry-run logs) and reference related issues or TODOs.
- Include screenshots or terminal snippets when modifying shells, prompts, or visual tooling to show the resulting UI.

## Security & Configuration Tips
- Age keys live at `~/.config/sops/age/keys.txt`; Home Manager generates them if absent. Do not commit decrypted files from `~/.config/secrets/`.
- To access a secret, read the managed file (e.g., `open ~/.config/secrets/openai-api-key | str trim`) and scope the value with `with-env` instead of exporting it globally.
