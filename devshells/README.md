# Development Shells

This directory contains modular Nix devShell configurations for various programming languages and use cases.

## Available Shells

> **Note:** When in the dotfiles directory, use `.#shell-name`. From other directories, use the full path `~/Development/dotfiles#shell-name`.

### `default`
Basic shell with git and nixfmt for dotfiles development.

```bash
nix develop        # or: nix develop .#default
```

**Includes:**
- Git
- nixfmt-classic
- uv (for `uvx` commands)

**MCP helper:**
- `mcp-nixos` alias pins UV caches to `.cache/` so `uvx mcp-nixos` works without extra setup; useful before launching Codex.

### `python-uv`
Python development with UV package manager.

```bash
nix develop .#python-uv
```

**Includes:**
- Python 3.12
- UV (fast Python package manager)
- Ruff (linter/formatter)
- Pyright (type checker)

### `ai-notebook`
Notebook-focused ML/AI environment with HuggingFace tooling and JupyterLab.

```bash
nix develop .#ai-notebook
```

**Includes:**
- Python 3.12 with JupyterLab, NumPy/Pandas/SciPy stack
- HuggingFace `transformers`, `datasets`, `accelerate`, `tokenizers`
- Vision tooling: OpenCV, scikit-image, Pillow, albumentations, Altair/Plotly
- Optional CPU PyTorch (Linux hosts) plus torchvision/torchaudio
- UV, Ruff, Pyright, Git LFS

**HuggingFace caches:**
- Models: `~/.cache/huggingface/hub`
- Transformers: `~/.cache/huggingface/transformers`

**Example usage:**
```bash
# Launch JupyterLab with AI helpers
jupyter lab

# Download a model or dataset
huggingface-cli download meta-llama/Llama-3.2-1B
python -c "from datasets import load_dataset; load_dataset('ag_news')"

# Fine-tune with Accelerate
python -m accelerate.commands.launch train.py
```

### `go`
Go development environment.

```bash
nix develop .#go
```

**Includes:**
- Go compiler
- gopls (language server)
- golangci-lint
- delve (debugger)

### `web-bun`
Modern web development with Bun runtime.

```bash
nix develop .#web-bun
```

**Includes:**
- Bun
- Node.js 20
- Yarn
- esbuild
- vscode-langservers-extracted

### `rust`
Rust development environment.

```bash
nix develop .#rust
```

**Includes:**
- Cargo & rustc
- rust-analyzer
- rustfmt
- clippy

## Usage from Any Directory

### Option 1: Direct Path Reference
Use the full path to your dotfiles:

```bash
cd ~/my-project
nix develop ~/Development/dotfiles#ai-notebook
```

### Option 2: Flake Registry Alias (Recommended)

**One-time setup:**
```bash
nix registry add dotfiles ~/Development/dotfiles

# Verify it worked
nix registry list | grep dotfiles
```

**Then from anywhere:**
```bash
cd ~/any-project
nix develop dotfiles#ai-notebook
```

Benefits: Shorter commands, cleaner paths, easy to remember!

### Option 3: Auto-loading with direnv (Best for per-project)

**Recommended: Combine registry + direnv for cleanest setup:**

```bash
# One-time: Set up registry (if not done already)
nix registry add dotfiles ~/Development/dotfiles

# In each project:
cd ~/my-ml-project
echo "use flake dotfiles#ai-notebook" > .envrc
direnv allow
```

**Alternative: Without registry (using full path):**
```bash
cd ~/my-ml-project
echo "use flake ~/Development/dotfiles#ai-notebook" > .envrc
direnv allow
```

Now the shell automatically activates when you `cd` into that directory!

### Option 4: Project-specific flake.nix

Create a `flake.nix` in your project that imports the shell:

```nix
{
  inputs = {
    dotfiles.url = "path:/Users/rasyidanakbar/Development/dotfiles";
  };

  outputs = { self, dotfiles }:
    let
      system = "aarch64-darwin";
    in {
      devShells.${system}.default = dotfiles.devShells.${system}.ai-notebook;
    };
}
```

Then simply:
```bash
cd ~/my-project
nix develop
```

### Quick Reference

| Method | Command | Pros |
|--------|---------|------|
| Direct path | `nix develop ~/Development/dotfiles#ai-notebook` | Simple, no setup |
| Registry | `nix develop dotfiles#ai-notebook` | Clean, short commands |
| direnv + registry | `echo "use flake dotfiles#ai-notebook" > .envrc` | Auto-loads, clean |
| Project flake | `nix develop` | Shareable, version-controlled |

## Adding New Shells

1. Create a new file in `devshells/` (e.g., `devshells/java.nix`)
2. Follow the pattern:
```nix
{ pkgs, ... }:

pkgs.mkShell {
  name = "java";
  packages = with pkgs; [ jdk maven ];
  shellHook = ''
    echo "Java development shell ready"
  '';
}
```
3. Add it to `flake.nix` imports:
```nix
java = importShell "java";
```
4. Test: `nix flake check`
