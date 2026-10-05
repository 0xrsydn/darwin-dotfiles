# pstack-pi integration

pstack-pi is installed as an external Pi package, not copied into this directory.
This directory contains documentation only. Do not add an `index.ts` loader while the package is installed.

## Release pin

- Repository: [0xrsydn/pstack-pi](https://github.com/0xrsydn/pstack-pi).
- Release: [v0.16.0](https://github.com/0xrsydn/pstack-pi/releases/tag/v0.16.0).
- Annotated tag commit: `2274745528d0bea38ae6ed23f90221e89a6e7c34`.
- Source: `git:github.com/0xrsydn/pstack-pi@v0.16.0`.
- Home Manager declaration: [modules/home/devtools/ai-tools.nix](../../../modules/home/devtools/ai-tools.nix).

The activation script installs the exact source when it is missing or differs from the configured release.
For immediate installation without a system rebuild:

```sh
pi install git:github.com/0xrsydn/pstack-pi@v0.16.0
pi list
```

Restart Pi or run `/reload` after installation.

## Declaration and activation

`pi install` records the package in `~/.pi/agent/settings.json`.
The package manifest declares `extensions/pstack/index.ts` and its skills separately.
Pi loads the extension at session startup or reload.
The extension registers `/setup-pstack` and the `pstack_task` tool without a skill invocation.

`/skill:poteto-mode` loads workflow instructions. It does not activate the extension.
A session started with `--no-skills` still loads the package extension and exposes `pstack_task` by default.
Package resource filters, `--no-extensions`, and tool selection can change this behavior.
No child process runs until a delegation call occurs.

Keep one package declaration for this repository.
Do not also copy the extension into `~/.pi/agent/extensions/` or this local extension tree.
Duplicate entry points can register the same command and tool twice.

## Model configuration

Run `/setup-pstack` to customize any of the 17 roles and panel lists.
Routes are stored in `~/.pi/agent/pstack-models.json` and read on each delegation call.
Keep personal credentials and provider routes outside the released package.

The local routing choice uses Grok 4.7 for fast roles and the custom Claude bridge for judgment roles.
The `medium` budget requests `high` thinking.
These choices are user configuration, not fixed package requirements.

Neither `poteto-agent` nor `general-purpose` has a fixed model.
Without a role or task model override, bundled agents inherit the active parent model.
Dotfiles set `openai-codex/gpt-6.1-sol` as the default for new parent sessions.
Existing sessions keep their selected model until changed through `/model`.

## Release procedure

1. Prepare the version, lockfile, changelog, and migration notes in a pstack-pi pull request.
2. Run a clean dependency install, typecheck, tests, and package validation.
3. Merge the reviewed pull request and verify its exact merged commit.
4. Create an annotated `v<version>` tag on that commit. Never move a published tag.
5. Publish a GitHub release with notes, the package archive, and `SHA256SUMS`.
6. Update both source references in the Home Manager activation script to the published tag.
7. Update this release record and install the new source locally.
8. Verify the installed source, version, and one active `pstack_task` registration with skills disabled.
9. Run Nix formatting, parsing, and `nix flake check` before applying the system configuration.

Use Jujutsu for change management. Use Git only for annotated tag operations unsupported by Jujutsu.
GitHub release publication does not imply npm registry publication.
Review and authorize `npm publish` separately.

## Validation of v0.16.0

- TypeScript checks and six tests passed against the merged commit.
- Package version fields agree on `0.16.0`.
- The annotated release tag points to the tested merged commit.
- The GitHub release includes a package archive and a SHA-256 checksum file.
- A startup probe with `--no-skills` found exactly one registered, active `pstack_task`.

See the [package README](https://github.com/0xrsydn/pstack-pi/blob/v0.16.0/README.md) for Pi primitives, routing precedence, and trust limits.
