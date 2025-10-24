# Desktop Setup Guide

This guide explains how to add desktop configurations to your NixOS system.

## Architecture

Desktop configuration is split into 3 layers:

### Layer 1: Base Infrastructure (`modules/nixos/*.nix`)
Hardware support that all desktops need:
- `audio.nix` - PipeWire audio stack
- `bluetooth.nix` - Bluetooth support
- `graphics.nix` - OpenGL/Vulkan acceleration
- `fonts.nix` - System fonts

### Layer 2: Desktop Environments (`modules/nixos/desktops/`)
System-level DE/WM configuration:
- `hyprland.nix` - Hyprland compositor
- `plasma.nix` - KDE Plasma 6
- `niri.nix` - Niri compositor
- `base.nix` - Shared DE settings

### Layer 3: User Configuration (`modules/home/rsydn/desktop/`)
Home Manager user-level configs:
- `base.nix` - GTK/Qt theming
- `apps/` - GUI application configs
- `wayland/` - Compositor user configs
- `themes/` - Theme configurations

## Quick Start

### 1. Update `flake.nix`

Add a new host configuration:

```nix
nixosConfigurations.my-desktop = nixpkgs.lib.nixosSystem {
  system = "x86_64-linux";
  modules = [
    ./modules/nixos/system.nix
    ./modules/nixos/hosts/desktop-dev.nix  # Your host config
    home-manager.nixosModules.home-manager {
      home-manager.users.rsydn = import ./modules/nixos/home/desktop.nix;
    }
  ];
};
```

### 2. Update `modules/nixos/system.nix`

Add desktop infrastructure imports:

```nix
{ lib, ... }: {
  imports = [
    ./users.nix
    ./network.nix
    ./ssh.nix
    ./containerization.nix
    # Add these for desktop:
    ./audio.nix
    ./bluetooth.nix
    ./graphics.nix
    ./fonts.nix
  ];
  # ... rest of config
}
```

### 3. Customize Host Configuration

Copy and modify `modules/nixos/hosts/desktop-dev.nix`:
- Set hostname
- Choose desktop environment (import from `desktops/`)
- Add hardware-specific settings (GPU drivers, etc.)

### 4. Enable Compositor in Home Manager

Edit `modules/home/rsydn/desktop/wayland/default.nix`:

```nix
imports = [
  ./hyprland  # Uncomment the compositor you want
  # ./niri
];
```

### 5. Build and Switch

```bash
# Check configuration
nix flake check

# Build
sudo nixos-rebuild switch --flake .#my-desktop
```

## Examples

### Hyprland Development Workstation
1. Host imports `desktops/hyprland.nix`
2. Home Manager imports `desktop/wayland/hyprland`
3. Customize keybinds in `desktop/wayland/hyprland/default.nix`

### KDE Plasma Gaming Rig
1. Host imports `desktops/plasma.nix`
2. Home Manager imports `desktop/base.nix` only
3. Enable Steam in host config
4. Add gaming packages

## Ricing Guide

All customization should happen in Layer 3 (`modules/home/rsydn/desktop/`):

1. **Themes**: Add theme files in `desktop/themes/`
2. **Compositor styling**: Edit `desktop/wayland/{hyprland,niri}/`
3. **Application configs**: Edit `desktop/apps/`
4. **Keep Layer 1 & 2 minimal** - they provide functionality, not aesthetics

## Switching Desktop Environments

Simply change the import in your host config:

```nix
# Before
imports = [ ../desktops/hyprland.nix ];

# After
imports = [ ../desktops/plasma.nix ];
```

Then rebuild your system.
