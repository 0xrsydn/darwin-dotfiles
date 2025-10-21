{ config, lib, ... }:
let
  themeName = "capr4n.omp.json";
  themeSource = ./capr4n.omp.json;
  themeConfigPath = "${config.xdg.configHome}/oh-my-posh/${themeName}";
in {
  programs.oh-my-posh = {
    enable = lib.mkDefault true;
    configFile = themeConfigPath;
  };

  xdg.configFile."oh-my-posh/${themeName}".source = themeSource;
}
