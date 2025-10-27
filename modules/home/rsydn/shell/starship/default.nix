{ lib, ... }: {
  programs.starship = {
    enable = lib.mkDefault true;
    enableNushellIntegration = true;
    settings = lib.importTOML ./starship.toml;
  };
}
