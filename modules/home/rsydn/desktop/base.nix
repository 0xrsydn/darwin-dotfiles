{ lib, pkgs, config, ... }: {
  # Base desktop user configuration

  # GTK theming
  gtk = {
    enable = lib.mkDefault true;
    theme = lib.mkDefault {
      name = "Adwaita-dark";
      package = pkgs.gnome-themes-extra;
    };
  };

  # Qt theming
  qt = {
    enable = lib.mkDefault true;
    platformTheme.name = lib.mkDefault "gtk";
    style.name = lib.mkDefault "adwaita-dark";
  };

  # XDG user directories
  xdg = {
    enable = true;
    userDirs = {
      enable = true;
      createDirectories = true;
    };
  };

  # Basic GUI packages
  home.packages = with pkgs;
    [
      # Add common desktop apps here
      # firefox
      # vscodium
    ];
}
