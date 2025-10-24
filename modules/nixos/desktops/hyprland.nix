{ pkgs, lib, ... }: {
  imports = [ ./base.nix ];

  # Hyprland - Dynamic tiling Wayland compositor
  programs.hyprland = {
    enable = lib.mkDefault true;
    xwayland.enable = lib.mkDefault true;
  };

  # Wayland-specific portal
  xdg.portal.wlr.enable = lib.mkDefault true;

  # Essential Wayland tools (system-level)
  environment.systemPackages = with pkgs; [
    # Wayland essentials
    wayland
    wl-clipboard
    wlr-randr

    # Screenshot & screen recording
    grim # Screenshot
    slurp # Region selector
    # wf-recorder  # Screen recording (optional)

    # Add your preferred apps here
    # kitty        # Terminal
    # wofi         # Launcher
    # waybar       # Bar
  ];
}
