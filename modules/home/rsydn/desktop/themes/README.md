# Themes

Add your theme configurations here. Each theme should set:
- GTK theme
- Qt theme
- Terminal colors
- Compositor colors (if applicable)
- Wallpapers

Example structure:
```nix
# catppuccin.nix
{ pkgs, ... }: {
  gtk.theme = {
    name = "Catppuccin-Mocha";
    package = pkgs.catppuccin-gtk;
  };

  # ... more theme settings
}
```
