# Local Codex package adapter

`codex.nix` adds the complete package layout required by Codex daemon startup.
The pinned Numtide package supplies binaries but lacks the manifest and bundled
ripgrep. The adapter copies the binaries without rebuilding Rust.

Remove this adapter and select `llmPkgs.codex` when Numtide supplies the complete
layout. Also remove the custom package export and adjust the flake check.

## Validation

Build the package and run its layout checks:

```sh
nix build .#codex
```

Test daemon provisioning outside the Nix sandbox:

```sh
python3 packages/codex-daemon-test.py ./result/bin/codex
```

The daemon test uses a temporary `CODEX_HOME`, disables automatic updates there,
and stops the test daemon. It does not use your normal Codex sessions or settings.

## Runtime limits

Codex copies the package into `~/.codex/packages/app-server-daemon`.
The copied Nix binaries still reference dependencies in `/nix/store`.
Keep the corresponding Nix system generation while using that daemon version.
After a Nix upgrade, `codex app-server daemon update --help` describes how to
select the current CLI package with `--from-cli`.

The adapter does not change your daemon update settings. Codex can automatically
update its private daemon independently of the CLI installed by Nix.

Only aarch64-darwin daemon startup has been tested locally. The derivation also
provides the required bubblewrap executable on Linux.
