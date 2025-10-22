# Repository Guidelines

## Project Structure & Module Organization
This flake manages both macOS (`macbook-pro`) and NixOS (`dev-vm`) hosts. `flake.nix` collects shared modules while `flake.lock` pins inputs. Platform modules live in `modules/darwin/` and `modules/nixos/`; the Linux base `system.nix` pulls in `users.nix`, `network.nix`, `ssh.nix`, and `containerization.nix`. Host overlays such as `modules/nixos/hosts/dev-vm.nix` add virtio tooling or per-machine packages. User-facing configuration sits under `modules/home/rsydn/` with `programs/`, `shell/`, and `devtools/`; Darwin layers `shell/nushell.nix` and Linux sticks to `shell/fish.nix`. Secrets remain encrypted in `secrets/*.sops.yaml` and appear at runtime under `~/.config/secrets/`.

## Build, Test & Development Commands
- `nix develop` – enter the dev shell with `git`, `nixfmt-classic`, and SOPS tooling prewired.
- `nix fmt` – format every Nix file; run before committing module or overlay changes.
- `XDG_CACHE_HOME=$PWD/.cache nix flake check` – evaluate all hosts without polluting the global cache.
- `darwin-rebuild --dry-run --flake .#macbook-pro` → `darwin-rebuild switch --flake .#macbook-pro` – preview then apply macOS updates.
- `nix build .#nixosConfigurations.dev-vm.config.system.build.toplevel` – validate the Linux VM closure before switching.

## Coding Style & Naming Conventions
Use two-space indentation, trailing commas, and lower-kebab filenames (e.g. `shell/nushell.nix`). Declare custom options in the `rsydn.*` namespace and prefer shared modules over ad-hoc host tweaks.

## Testing Guidelines
Treat `nix flake check` as mandatory gatekeeping. Capture activation output (`darwin-rebuild --dry-run`, `nix build .#nixosConfigurations.dev-vm…`) and attach summaries to reviews. Co-locate regression tests next to their modules with the `<option-name>.nix` pattern.

## Commit & Pull Request Guidelines
Keep commit subjects short and imperative (`add dev-vm virtualization module`) and scope each commit narrowly. PRs should list validation commands, link issues or TODOs, and include screenshots or terminal snippets when modifying prompts, Tailscale, or SSH flows.

## Security & Configuration Tips
Age keys live at `~/.config/sops/age/keys.txt`; regenerate via Home Manager if missing. Read secrets from the managed files (`open ~/.config/secrets/openai-api-key | str trim`) and scope them with `with-env`. Tailscale and OpenSSH run by default on Linux; rotate keys regularly and audit `services.tailscale.extraUpFlags` before enabling exit nodes.
