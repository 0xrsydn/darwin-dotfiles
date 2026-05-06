# Repository Guidelines

## Project Structure & Module Organization

Shared logic lives in `flake.nix`, with inputs pinned in `flake.lock`. Platform modules sit under `modules/darwin/` and `modules/nixos/`; Linux hosts compose `modules/nixos/system.nix` plus `users.nix`, `network.nix`, `ssh.nix`, and `containerization.nix`. Host-specific configs live at root level in `hosts/` (e.g. `hosts/dev-vm.nix`, `hosts/desktop.nix`). Home Manager layers are under `modules/home/` with `programs/`, `shell/`, and `devtools/`. Secrets stay encrypted in `secrets/*.sops.yaml` and surface at runtime in `~/.config/secrets/`.

Custom packages live in `packages/` and are exported via `packages/default.nix`. Each package has its own derivation file (e.g. `packages/osgrep.nix`). Packages are exported in the flake's `packages` output and can be built individually with `nix build .#osgrep`. The `checks` output ensures all packages build during `nix flake check`. To reference the current system in package definitions, use `pkgs.stdenv.hostPlatform.system` instead of the deprecated `pkgs.system`. Development shells in `shells/` receive custom packages through the `customPkgs` argument.

## Build, Test, and Development Commands

Use `nix develop` to enter the project shell with `git`, `nixfmt`, and SOPS ready. Run `nix fmt` before committing to format all Nix sources. `XDG_CACHE_HOME=$PWD/.cache nix flake check` validates every host without polluting the global cache. For macOS changes, run `darwin-rebuild --dry-run --flake .#macbook-pro` and follow with `darwin-rebuild switch --flake .#macbook-pro`. Validate the Linux VM closure via `nix build .#nixosConfigurations.dev-vm.config.system.build.toplevel`.

## Coding Style & Naming Conventions

Indent with two spaces and keep trailing commas in attribute sets. Prefer lower-kebab filenames (e.g. `package/nushell.nix`), and expose custom options under the `rsydn.*` namespace. Format Nix with `nix fmt`; avoid ad-hoc host tweaks when a shared module fits.

## Testing Guidelines

Treat `nix flake check` as the minimum gate; capture its output for reviews. When adjusting host builds, keep dry-run transcripts (`darwin-rebuild --dry-run`, `nix build .#nixosConfigurations.dev-vm…`) to share in PRs. Co-locate regression tests next to their modules using the `<option-name>.nix` pattern.

## Commit & Pull Request Guidelines

Write imperative commit subjects such as `add dev-vm virtualization module`, and keep each commit narrowly scoped. PRs should list validation commands run, link related issues or TODOs, and attach screenshots or terminal snippets when touching prompts, Tailscale, or SSH flows.

## Security & Configuration Tips

Age keys live at `~/.config/sops/age/keys.txt`; regenerate via Home Manager if missing. Access secrets with `open ~/.config/secrets/<name> | str trim` and scope them using `with-env`. Audit `services.tailscale.extraUpFlags` before enabling exit nodes, and rotate SSH/Tailscale keys regularly.
