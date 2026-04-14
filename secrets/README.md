# Secrets with sops-nix

This repo wires [`sops-nix`](https://github.com/Mic92/sops-nix) into the Home Manager profile so secrets are decrypted on-demand into `~/.config/secrets`. The module is enabled by default and auto-generates an Age key if one does not already exist. Only the *encrypted* payloads under `secrets/*.sops.yaml` are meant to live in git; decrypted files never leave your machine.

## One-time setup
1. Ensure `age` and `sops` are available (e.g. `nix develop` or `nix profile install nixpkgs#age nixpkgs#sops`).
2. Generate or import an Age key. Either let Home Manager create one automatically on first activation or run `age-keygen -o ~/.config/sops/age/keys.txt` yourself.
3. Capture the public half with `age-keygen -y -f ~/.config/sops/age/keys.txt` and add it to the `recipients` list in each encrypted file (`age1…`). Commit the public key under version control or share it through your password manager so other hosts can decrypt.
4. (Optional) Store the private key securely in macOS Keychain or 1Password (`security add-generic-password …`) so rebuilds work without manual prompts.

## Managing secrets
- Global shell env vars live in one encrypted YAML file: `secrets/global-env.sops.yaml`.
- Home Manager decrypts that file to `~/.config/secrets/global-env.yaml` during activation.
- Nushell reads `global-env.yaml` on startup and exports each top-level key as an environment variable.
- Only the encrypted file is tracked in git; plaintext stays local.

Example Darwin configuration:

```nix
rsydn.secrets = {
  enable = true;
  defaultSopsFile = ../../../secrets/global-env.sops.yaml;
  secrets."global-env" = {
    format = "yaml";
    key = "";
    path = "${config.xdg.configHome}/secrets/global-env.yaml";
  };
};
```

Create or update global env vars by running:

```bash
SOPS_AGE_KEY_FILE=$HOME/.config/sops/age/keys.txt \
  sops secrets/global-env.sops.yaml
```

Add entries like:

```yaml
OPENAI_API_KEY: sk-...
ANTHROPIC_API_KEY: sk-ant-...
GITHUB_TOKEN: ghp_...
```

After `darwin-rebuild switch --flake .#macbook-pro`, the decrypted file is refreshed and every new Nushell session automatically gets:

```nu
$env.OPENAI_API_KEY
$env.ANTHROPIC_API_KEY
$env.GITHUB_TOKEN
```

For secrets that should stay file-based instead of being auto-exported, you can still declare extra entries under `rsydn.secrets.secrets` with their own `path`, `format`, and `key`.

## Rotating keys
If you regenerate your Age key, re-encrypt the file with the new recipient (`sops updatekeys secrets/global-env.sops.yaml`) and re-run `darwin-rebuild --dry-run --flake .#macbook-pro` to verify the deployment. Remember to remove old recipients so machines without access can no longer decrypt.

## Frequently asked questions
- **Where do encrypted files live?** In this repo under `secrets/*.sops.yaml`; they are safe to commit.
- **Where does plaintext live?** At runtime under `~/.config/secrets/*` (managed by Home Manager). Keep permissions tight and never add these paths to git.
- **How do I share secrets with another machine?** Copy the Age public key from that machine into the `recipients` list, re-run `sops updatekeys`, commit, then pull and rebuild on the other host.
- **Can I keep using `.env`?** Yes—encrypt it (e.g. `secrets/project.env.sops`) and load it with `sops exec-env` inside `direnv` so per-project shells receive the decrypted variables without storing them on disk.
