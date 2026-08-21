# Notes authoring in Neovim

This module provides a Neovim interface for the personal website's public Notes
workflow. It is a native Lua integration and does not add a third-party plugin.

The website repository remains the source of truth for Entry creation,
validation, publication timestamps, media conversion, and builds. Neovim only
calls the existing Bun scripts.

## Requirements

- The website repository is available at
  `~/Development/MyWeb/magnum-opus/main`.
- `direnv` is installed and the website `.envrc` is allowed.
- The website development shell provides Bun.

Set `RASYIDANAF_SITE_ROOT` before starting Neovim to use another checkout:

```sh
export RASYIDANAF_SITE_ROOT=/path/to/rasyidan-personal-web
```

## Commands and mappings

The Notes group uses the local leader (`\`).

| Command | Mapping | Action |
| --- | --- | --- |
| `:NotesNewLog` | `\nl` | Prompt for an optional title and tags, create a Log draft, and open it |
| `:NotesNewNote` | `\nn` | Prompt for a required title and optional tags, create a Note draft, and open it |
| `:NotesPublish` | `\np` | Save and publish the current Entry after confirmation |
| `:NotesValidate` | `\nv` | Validate public Notes metadata, routes, lifecycle, tags, and media |
| `:NotesBuild` | `\nb` | Run the complete production build |

`NotesPublish` accepts only Markdown files inside `vault/public-notes/`. It
does not commit, push, or deploy. Review the Jujutsu diff and push the website
repository separately.

## Normal workflow

1. Press `\nl` for a Log or `\nn` for a titled Note.
2. Write and save the Entry.
3. Press `\np` and confirm publication.
4. Press `\nv`, then `\nb`.
5. Review, describe, and push the website change with Jujutsu.

The publication command reloads the current buffer after the repository script
writes `publishedAt` and processes referenced images.

## Apply the configuration

Home Manager owns the Neovim configuration. Apply dotfiles changes with:

```sh
cd ~/Development/dotfiles
sudo darwin-rebuild switch --flake .#macbook-pro
```
