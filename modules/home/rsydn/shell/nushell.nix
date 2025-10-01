{ config, pkgs, lib, ... }:
let
  themeName = "capr4n.omp.json";
  themeSource = ./oh-my-posh/capr4n.omp.json;
  themeConfigPath = "${config.xdg.configHome}/oh-my-posh/${themeName}";
  profileBin = "${config.home.profileDirectory}/bin";
  systemBin = "/run/current-system/sw/bin";
  defaultBin = "/nix/var/nix/profiles/default/bin";
  darwinHomebrewDir = if pkgs.stdenv.hostPlatform.isAarch64 then
    "/opt/homebrew"
  else
    "/usr/local";
  homebrewBin = "${darwinHomebrewDir}/bin";
  homebrewSbin = "${darwinHomebrewDir}/sbin";
  homebrewPaths = if pkgs.stdenv.hostPlatform.isDarwin then
    lib.unique [ homebrewBin homebrewSbin ]
  else
    [ ];
  formatPathList = paths: lib.concatMapStrings (path: "      \"${path}\"\n") paths;
in {
  programs.nushell.enable = lib.mkDefault true;

  programs.nushell.envFile.text = ''
    let nix_paths = [
${formatPathList [ profileBin systemBin defaultBin ]}    ]

    let homebrew_paths = [
${formatPathList homebrewPaths}    ]

    let path_candidates = ($nix_paths | append $homebrew_paths | flatten)

    if ($env.PATH? == null) {
      $env.PATH = $path_candidates
    } else {
      for path in $path_candidates {
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
