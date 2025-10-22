# Repository Guidelines

## Project Structure & Module Organization
- `flake.nix` defines shared helpers plus Darwin (`macbook-pro`) and NixOS (`dev-vm`) hosts; `flake.lock` pins inputs.
- `modules/darwin/` holds macOS system modules; `modules/nixos/` mirrors that for Linux (base `system.nix` imports `users.nix`, `network.nix`, `ssh.nix`, `containerization.nix`).
- Host overlays live under `modules/nixos/hosts/`—e.g., `dev-vm.nix` adds virtio tooling and host-only packages.
- User configuration is in `modules/home/rsydn/` with subdirectories for `programs/`, `shell/`, and `devtools/`; Darwin layers on `shell/nushell.nix` while Linux sticks to `shell/fish.nix`.
- Secrets stay in `secrets/*.sops.yaml`; decrypted files appear under `~/.config/secrets/` at activation and must not be committed.

## Build, Test & Development Commands
- `nix develop` – enter the flake dev shell with `git`, `nixfmt-classic`, SOPS/Age helpers.
- `nix fmt` – format all Nix sources; run before commits touching modules or overlays.
- `XDG_CACHE_HOME=$PWD/.cache nix flake check` – lint and eval every host without polluting the global cache.
- `darwin-rebuild --dry-run --flake .#macbook-pro` / `darwin-rebuild switch --flake .#macbook-pro` – preview or apply macOS changes.
- `nix build .#nixosConfigurations.dev-vm.config.system.build.toplevel` – make sure the Linux VM evaluates and builds before switching.

## Coding Style & Naming Conventions
- Use two-space indentation, trailing commas, and lower-kebab filenames (`shell/nushell.nix`).
- Declare custom options under the `rsydn.*` namespace (e.g., `rsydn.containerization`, `rsydn.devTools`).
- Prefer declarative package toggles and shared modules over ad-hoc host tweaks; keep host-specific overrides in `hosts/`.

## Testing Guidelines
- Treat `nix flake check` as mandatory before PRs or `switch` operations.
- Capture key activation output: `darwin-rebuild --dry-run` for macOS, `nix build .#nixosConfigurations.dev-vm…` for the VM, and attach summaries in reviews.
- Co-locate regression tests with the option/module they guard using the `<option-name>.nix` pattern when practical.

## Commit & Pull Request Guidelines
- Write short, imperative subjects (`add dev-vm virtualization module`); keep each commit scoped to one change.
- In PRs, list validation steps (`nix flake check`, host-specific builds) and link related issues or TODOs.
- Provide screenshots or terminal snippets when altering shell prompts, Tailscale/SSH flows, or other UX-facing pieces.

## Security & Configuration Tips
- Age keys live at `~/.config/sops/age/keys.txt`; regenerate via Home Manager if missing.
- Access secrets by reading the managed files (`open ~/.config/secrets/openai-api-key | str trim`) and scope them with `with-env` instead of exporting globally.
- Tailscale and OpenSSH run by default on Linux; rotate auth keys regularly and audit `services.tailscale.extraUpFlags` when enabling exit nodes.
