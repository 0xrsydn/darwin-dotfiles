# Development Shells

This directory contains modular Nix devShell configurations for various programming languages and use cases.

## Available Shells

### `default`
Basic shell with git and nixfmt for dotfiles development.

```bash
nix develop
```

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

### `ml-ai`
Machine Learning and AI development with HuggingFace model management.

```bash
nix develop .#ml-ai
```

**Includes:**
- Python 3.12 with huggingface-hub
- `huggingface-cli` for downloading models
- UV for package management
- Git LFS for large files
- Ruff and Pyright

**Model cache:** `~/.cache/huggingface` (persistent across projects)

**Example usage:**
```bash
# Download a TTS model
huggingface-cli download facebook/mms-tts-eng

# Download a small LLM
huggingface-cli download meta-llama/Llama-3.2-1B

# Download specific files only
huggingface-cli download openai/whisper-large-v3 --include "*.json" "*.safetensors"

# Use in your project
uv init my-ml-project
cd my-ml-project
uv add transformers torch
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

### `zig-nightly` (optional)
Zig nightly development (only available if zig overlay is working).

```bash
nix develop .#zig-nightly
```

## Usage from Any Directory

You can use these shells from anywhere by referencing your dotfiles:

```bash
# From any directory
cd ~/my-project
nix develop ~/Development/dotfiles#ml-ai
```

## Auto-loading with direnv

To automatically load a shell when entering a directory:

```bash
cd ~/my-ml-project
echo "use flake ~/Development/dotfiles#ml-ai" > .envrc
direnv allow
```

Now the shell automatically activates when you `cd` into that directory!

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
