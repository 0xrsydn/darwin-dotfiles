{
  pkgs,
  lib,
  user,
  ...
}:
{
  imports = [ ../base.nix ];

  # System-level: Enable Hyprland
  programs.hyprland = {
    enable = lib.mkDefault true;
    xwayland.enable = lib.mkDefault true;
  };

  # Wayland-specific portal
  xdg.portal.wlr.enable = lib.mkDefault true;

  # System packages: Wayland essentials
  environment.systemPackages = with pkgs; [
    # Wayland essentials
    wayland
    wl-clipboard
    wlr-randr

    # Screenshot & screen recording
    grim # Screenshot
    slurp # Region selector
    # wf-recorder  # Screen recording (optional)
  ];

  # User-level: Hyprland configuration
  home-manager.users.${user} = {
    wayland.windowManager.hyprland = {
      enable = lib.mkDefault true;
      xwayland.enable = lib.mkDefault true;

      settings = {
        # Minimal config - expand as needed
        "$mod" = "SUPER";

        # Example keybinds
        bind = [
          "$mod, Return, exec, kitty" # Terminal
          "$mod, Q, killactive"
          "$mod, M, exit"
          "$mod, F, fullscreen"
          "$mod, Space, togglefloating"

          # Move focus
          "$mod, h, movefocus, l"
          "$mod, l, movefocus, r"
          "$mod, k, movefocus, u"
          "$mod, j, movefocus, d"
        ];

        # Visual settings
        general = {
          gaps_in = 5;
          gaps_out = 10;
          border_size = 2;
        };

        decoration = {
          rounding = 8;
        };
      };
    };

    # User packages: Hyprland utilities
    home.packages = with pkgs; [
      # Uncomment as needed:
      # wofi       # Launcher
      # waybar     # Status bar
      # dunst      # Notifications
    ];
  };
}
