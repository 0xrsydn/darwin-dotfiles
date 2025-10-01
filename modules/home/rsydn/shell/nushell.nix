{ config, lib, ... }:
let
  themeName = "capr4n.omp.json";
  themeSource = ./oh-my-posh/capr4n.omp.json;
  themeConfigPath = "${config.xdg.configHome}/oh-my-posh/${themeName}";
  profileBin = "${config.home.profileDirectory}/bin";
  systemBin = "/run/current-system/sw/bin";
  defaultBin = "/nix/var/nix/profiles/default/bin";
in {
  programs.nushell.enable = lib.mkDefault true;

  programs.nushell.envFile.text = ''
    let nix_paths = [
      "${profileBin}"
      "${systemBin}"
      "${defaultBin}"
    ]

    if ($env.PATH? == null) {
      $env.PATH = $nix_paths
    } else {
      for path in $nix_paths {
        if not ($env.PATH | any {|it| $it == $path}) {
          $env.PATH = ($env.PATH | append $path)
        }
      }
    }

    $env.NIX_PROFILES = "/run/current-system/sw ${config.home.profileDirectory}"
  '';

  programs.oh-my-posh = {
    enable = lib.mkDefault true;
    enableNushellIntegration = lib.mkDefault true;
    configFile = themeConfigPath;
  };

  xdg.configFile."oh-my-posh/${themeName}".source = themeSource;
}
