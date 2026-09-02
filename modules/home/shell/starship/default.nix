{ lib, ... }:
{
  programs.starship = {
    enable = lib.mkDefault true;
    enableFishIntegration = true;
    enableNushellIntegration = true;
    enableZshIntegration = true;
    settings = lib.importTOML ./starship.toml;
  };
}
