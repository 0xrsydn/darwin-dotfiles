{ config, lib, ... }:
let
  themeName = "capr4n.omp.json";
  themeSource = ./oh-my-posh/capr4n.omp.json;
  themeConfigPath = "${config.xdg.configHome}/oh-my-posh/${themeName}";
in {
  programs.nushell.enable = lib.mkDefault true;

  programs.oh-my-posh = {
    enable = lib.mkDefault true;
    enableNushellIntegration = lib.mkDefault true;
    configFile = themeConfigPath;
  };

  xdg.configFile."oh-my-posh/${themeName}".source = themeSource;
}
