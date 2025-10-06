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
  formatPathList = paths:
    lib.concatMapStrings (path: "      \"${path}\"\n") paths;
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

        # Load sops-managed API keys as environment variables
        let secrets_dir = "${config.xdg.configHome}/secrets"

        def load-secret [secret_name: string, env_var: string] {
          let secret_file = ($secrets_dir | path join $secret_name)
          if ($secret_file | path exists) {
            load-env { $env_var: (open $secret_file | str trim) }
          }
        }

        load-secret "zai-api-key" "ZAI_API_KEY"
        load-secret "openai-api-key" "OPENAI_API_KEY"
        load-secret "openrouter-api-key" "OPENROUTER_API_KEY"
        load-secret "moonshot-api-key" "MOONSHOT_API_KEY"
        load-secret "anthropic-api-key" "ANTHROPIC_API_KEY"
        load-secret "exa-api-key" "EXA_API_KEY"
        load-secret "fal-api-key" "FAL_API_KEY"
        load-secret "groq-api-key" "GROQ_API_KEY"
        load-secret "firecrawl-api-key" "FIRECRAWL_API_KEY"
  '';

  programs.oh-my-posh = {
    enable = lib.mkDefault true;
    enableNushellIntegration = lib.mkDefault true;
    configFile = themeConfigPath;
  };

  xdg.configFile."oh-my-posh/${themeName}".source = themeSource;
}
