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
- `TYPESAFE_API_KEY` or `TYPESAFEAI_API_KEY` is available for tag classification.
- `OPENROUTER_API_KEY`, `OPENAI_API_KEY`, or `TAG_GENERATOR_API_KEY` is available when a new tag must be created.

Set `RASYIDANAF_SITE_ROOT` before starting Neovim to use another checkout:

```sh
export RASYIDANAF_SITE_ROOT=/path/to/rasyidan-personal-web
```

## Commands and mappings

The Notes group uses the local leader (`\`).

| Command | Mapping | Action |
| --- | --- | --- |
| `:NotesNewLog` | `\nl` | Prompt for an optional title, create an untagged Log draft, and open it |
| `:NotesNewNote` | `\nn` | Prompt for a required title, create an untagged Note draft, and open it |
| `:NotesPublish` | `\np` | Save and publish the current Entry after confirmation |
| `:ContentAutoTag` | `\nt` | Save and automatically tag the current Draft Note or Blog Post |
| `:NotesValidate` | `\nv` | Validate public Notes metadata, routes, lifecycle, tags, and media |
| `:NotesBuild` | `\nb` | Run the complete production build |

`NotesPublish` accepts only Markdown files inside `vault/public-notes/`. It
does not commit, push, or deploy. Review the Jujutsu diff and push the website
repository separately.

`ContentAutoTag` accepts Drafts in `vault/public-notes/` and `vault/blog/`.
TypeSafe selects and validates tags. The command reuses tags collected from both
content areas. If no existing tag fits, an OpenAI-compatible generator proposes
new tags and TypeSafe validates them before the command updates frontmatter.

## Normal workflow

1. Press `\nl` for a Log or `\nn` for a titled Note.
2. Write and save the Entry.
3. Press `\nt` to generate tags and review the notification.
4. Press `\np` and confirm publication.
5. Press `\nv`, then `\nb`.
6. Review, describe, and push the website change with Jujutsu.

The publication command reloads the current buffer after the repository script
writes `publishedAt` and processes referenced images.

## Apply the configuration

Home Manager owns the Neovim configuration. Apply dotfiles changes with:

```sh
cd ~/Development/dotfiles
sudo darwin-rebuild switch --flake .#macbook-pro
```
