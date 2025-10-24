# Desktop Environments

This directory contains system-level desktop environment configurations for NixOS desktop hosts.

## Structure

```
desktops/
├── base.nix                     # Shared desktop settings (XDG portals, polkit, gvfs)
├── plasma.nix                   # KDE Plasma 6 + SDDM
├── hyprland/                    # Hyprland tiling compositor
│   └── default.nix
├── gaming.nix                   # Steam, Proton, GameMode, gaming tools
├── apps/                        # Desktop applications
│   ├── browsers.nix             # Brave, Zen Browser
│   └── terminals.nix            # Alacritty (Dracula theme)
├── themes/                      # Theme configurations
│   ├── catppuccin.nix           # Catppuccin GTK/Qt theme
│   └── default.nix              # Adwaita default theme
└── hardware-configuration.nix   # Hardware-specific settings (generated)
```

## Available Desktop Environments

### KDE Plasma 6 (`plasma.nix`)
- Full-featured desktop with SDDM display manager
- Wayland-first with X11 fallback
- Includes essential KDE applications (commented out by default)
- User-level Plasma configuration via Home Manager (optional)

### Hyprland (`hyprland/default.nix`)
- Dynamic tiling Wayland compositor
- Minimal default keybinds (SUPER key)
- Includes Wayland utilities: wl-clipboard, grim, slurp
- User-level configuration for keybinds, visual settings

## Additional Modules

### Gaming (`gaming.nix`)
**Features:**
- Steam with Proton GE compatibility
- GameMode for performance optimization
- 32-bit graphics support for games
- Wine, Winetricks, Lutris, Heroic launcher
- MangoHud for FPS overlay
- Discord for communication
- Increased inotify watchers for modding tools

### Apps (`apps/`)
**Browsers** (`browsers.nix`):
- Brave, Zen Browser (enabled by default)

**Terminals** (`terminals.nix`):
- Alacritty enabled with JetBrains Mono + Dracula theme
- Kitty and WezTerm explicitly disabled to keep a single default

### Themes (`themes/`)
**Catppuccin** (`catppuccin.nix`):
- Soothing pastel theme for GTK and Qt
- Mocha variant with blue accents
- Kvantum Qt theme engine
- Papirus icon theme
- Catppuccin cursor theme

**Default** (`default.nix`):
- Adwaita theme (GNOME default)
- Minimal theming setup

## Usage

### Single Desktop Environment

Import one desktop environment in your host configuration:

```nix
# modules/nixos/hosts/your-host.nix
{
  imports = [
    ../desktops/plasma.nix
    # OR
    # ../desktops/hyprland
  ];
}
```

### Multi-Desktop Setup (Switch at Login)

The current desktop host uses both KDE Plasma (for gaming) and Hyprland (for development):

```nix
# modules/nixos/hosts/desktop.nix
{
  imports = [
    # Hardware
    ../desktops/hardware-configuration.nix

    # Desktop Environments
    ../desktops/plasma.nix      # KDE Plasma (for gaming)
    ../desktops/hyprland        # Hyprland (for development)

    # Desktop Apps & Theme
    ../desktops/apps/browsers.nix
    ../desktops/apps/terminals.nix
    ../desktops/themes/catppuccin.nix

    # Gaming & Features
    ../desktops/gaming.nix
    ../bluetooth.nix
  ];

  boot = {
    loader.systemd-boot.enable = true;
    loader.efi.canTouchEfiVariables = true;
    kernelPackages = pkgs.linuxPackages_cachyos-lts;
  };

  networking.hostName = "desktop";
  system.stateVersion = "24.05";
}
```

**Boot Configuration:**
- CachyOS LTS kernel for gaming performance
- Systemd-boot for EFI boot management

**Switch Desktop at Login:**
- SDDM login screen shows both Plasma and Hyprland sessions
- Select desired environment before logging in

## Base Desktop Settings (`base.nix`)

Shared settings imported by all desktop environments:

- **XDG Portals**: Desktop integration, file picker, screen sharing
- **PolicyKit**: Privilege escalation for GUI apps
- **GVFS**: Trash, mounting, network drives
- **Common Packages**: pavucontrol, networkmanagerapplet

## Adding a New Desktop Environment

1. Create a new file (e.g., `gnome.nix`)
2. Import `./base.nix` for shared settings
3. Enable the desktop environment and display manager
4. Add essential system packages
5. Configure user-level settings via Home Manager

Example:

```nix
{ lib, pkgs, user, ... }: {
  imports = [ ./base.nix ];

  services.xserver = {
    enable = true;
    desktopManager.gnome.enable = true;
    displayManager.gdm.enable = true;
  };

  environment.systemPackages = with pkgs; [
    gnome-tweaks
  ];
}
```

## Testing Desktop Changes

```bash
# Dry-run to check closure
nix build .#nixosConfigurations.desktop.config.system.build.toplevel --dry-run

# Build and switch
sudo nixos-rebuild switch --flake .#desktop

# Format before committing
nix fmt
```
