# Secrets with sops-nix

This repository uses [`sops-nix`](https://github.com/Mic92/sops-nix) with Home Manager. SOPS keeps encrypted values in Git. Home Manager decrypts each global environment variable to a separate runtime file under `~/.config/secrets/global-env/`.

## One-time setup

1. Enter `nix develop` so `age` and `sops` are available.
2. Generate or import an Age key. Home Manager can generate one during activation. You can also run:

   ```bash
   age-keygen -o ~/.config/sops/age/keys.txt
   ```

3. Get the public key:

   ```bash
   age-keygen -y -f ~/.config/sops/age/keys.txt
   ```

4. Add the public key as a recipient in each encrypted SOPS file.
5. Store the private key in a secure backup such as 1Password or macOS Keychain.

## Global environment secrets

The encrypted source is `secrets/global-env.sops.yaml`. It contains a flat map of environment variable names and encrypted values.

Home Manager declares each key in `modules/darwin/home/default.nix`. During activation, sops-nix writes one mode `0400` file per key:

```text
~/.config/secrets/global-env/OPENAI_API_KEY
~/.config/secrets/global-env/ANTHROPIC_API_KEY
```

Zsh and Nushell read these files and export each filename as an environment variable. The loaders do not evaluate secret values as shell code.

Edit the encrypted source with:

```bash
SOPS_AGE_KEY_FILE=$HOME/.config/sops/age/keys.txt \
  sops secrets/global-env.sops.yaml
```

Use a flat YAML structure:

```yaml
OPENAI_API_KEY: sk-...
ANTHROPIC_API_KEY: sk-ant-...
GITHUB_TOKEN: ghp_...
```

When you add or remove a key, also update `globalEnvironmentSecretNames` in `modules/darwin/home/default.nix`. Then apply the configuration:

```bash
darwin-rebuild switch --flake .#macbook-pro
```

Open a new Zsh or Nushell session after activation. Access values as follows:

```zsh
print -r -- "$OPENAI_API_KEY"
```

```nu
$env.OPENAI_API_KEY
```

Do not print real secret values during routine validation. Test only whether a variable exists.

## File-based secrets

Secrets that applications consume as files should stay file-based. Declare each entry under `rsydn.secrets.secrets` with its own `path`, `format`, and `key`.

For project-specific environment variables, use an encrypted project file with `sops exec-env` through direnv. Do not add project secrets to the global shell environment.

## Rotating keys

If you replace an Age key, update the recipients:

```bash
sops updatekeys secrets/global-env.sops.yaml
```

Remove old recipients, then validate the configuration:

```bash
darwin-rebuild --dry-run --flake .#macbook-pro
```

Only encrypted SOPS files belong in Git. Never add decrypted files from `~/.config/secrets/`.
