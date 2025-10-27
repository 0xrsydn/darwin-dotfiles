{ lib, pkgs, user, ... }: {
  # Catppuccin theme configuration
  # Soothing pastel theme for both GTK and Qt applications
  # Works with KDE Plasma, Hyprland, and other desktop environments

  # System packages: Theme engines and Catppuccin themes
  environment.systemPackages = with pkgs; [
    libsForQt5.qtstyleplugin-kvantum # Kvantum Qt theme engine
    qt6Packages.qtstyleplugin-kvantum # Kvantum for Qt6
    catppuccin-kvantum # Catppuccin theme for Kvantum
    catppuccin-cursors # Catppuccin cursor theme
  ];

  home-manager.users.${user} = {
    # GTK theming - Catppuccin Mocha variant
    gtk = {
      enable = true;
      theme = {
        name = "Catppuccin-Mocha-Standard-Blue-Dark";
        package = pkgs.catppuccin-gtk.override {
          accents = [
            "blue"
          ]; # Options: blue, flamingo, green, lavender, maroon, mauve, peach, pink, red, rosewater, sapphire, sky, teal, yellow
          size = "standard"; # Options: standard, compact
          variant = "mocha"; # Options: latte, frappe, macchiato, mocha
        };
      };

      # GTK icon theme
      iconTheme = {
        name = "Papirus-Dark";
        package = pkgs.papirus-icon-theme;
      };
    };

    # Qt theming - Catppuccin via Kvantum
    qt = {
      enable = true;
      platformTheme.name = "kvantum";
      style.name = "kvantum";
    };

    # Kvantum configuration
    xdg.configFile."Kvantum/kvantum.kvconfig".text = ''
      [General]
      theme=Catppuccin-Mocha-Blue
    '';

    # Cursor theme
    home.pointerCursor = {
      name = "catppuccin-mocha-blue-cursors";
      package = pkgs.catppuccin-cursors.mochaBlue;
      size = 24;
      gtk.enable = true;
      x11.enable = true;
    };

    # XDG user directories for desktop environments
    xdg.userDirs = {
      enable = true;
      createDirectories = true;
    };
  };
}
