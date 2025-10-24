# Desktop Environments

This directory contains system-level desktop environment configurations.

## Available Desktop Environments

- `hyprland.nix` - Dynamic tiling Wayland compositor
- `plasma.nix` - KDE Plasma 6 desktop environment
- `niri.nix` - Scrollable-tiling Wayland compositor
- `base.nix` - Shared desktop settings (imported by all DEs)

## Usage

Import one desktop environment in your host configuration:

```nix
# modules/nixos/hosts/your-host.nix
{
  imports = [
    ../desktops/hyprland.nix
    # OR
    # ../desktops/plasma.nix
    # OR
    # ../desktops/niri.nix
  ];
}
```

## Adding a New Desktop Environment

1. Create a new file (e.g., `gnome.nix`)
2. Import `./base.nix`
3. Enable the desktop environment
4. Add essential system packages
