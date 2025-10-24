{ lib, pkgs, ... }: {
  fonts = {
    enableDefaultPackages = lib.mkDefault true;

    packages = with pkgs; [
      # Nerd Fonts for terminal icons
      (nerdfonts.override { fonts = [ "FiraCode" "JetBrainsMono" "Iosevka" ]; })

      # Core fonts
      noto-fonts
      noto-fonts-cjk
      noto-fonts-emoji
      liberation_ttf

      # Code fonts
      fira-code
      jetbrains-mono
    ];

    fontconfig = {
      enable = lib.mkDefault true;
      defaultFonts = {
        monospace = [ "JetBrains Mono" "FiraCode Nerd Font" ];
        sansSerif = [ "Noto Sans" ];
        serif = [ "Noto Serif" ];
        emoji = [ "Noto Color Emoji" ];
      };
    };
  };
}
