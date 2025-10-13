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

  programs.nushell.extraConfig = ''
    # Dotfiles QA validation command
    def dotfiles-qa [] {
      let dotfiles_dir = "${config.home.homeDirectory}/Development/dotfiles"

      print $"(ansi green_bold)Running dotfiles QA validation...(ansi reset)\n"

      # Step 1: Format check
      print $"(ansi blue)1. Formatting nix files...(ansi reset)"
      cd $dotfiles_dir
      nix fmt .
      if $env.LAST_EXIT_CODE != 0 {
        print $"(ansi red_bold)✗ Formatting failed(ansi reset)"
        return
      }
      print $"(ansi green)✓ Formatting complete(ansi reset)\n"

      # Step 2: Flake check
      print $"(ansi blue)2. Running flake check...(ansi reset)"
      nix flake check
      if $env.LAST_EXIT_CODE != 0 {
        print $"(ansi red_bold)✗ Flake check failed(ansi reset)"
        return
      }
      print $"(ansi green)✓ Flake check passed(ansi reset)\n"

      # Step 3: Build (without activation)
      print $"(ansi blue)3. Building darwin configuration (no activation)...(ansi reset)"
      darwin-rebuild build --flake $"($dotfiles_dir)#macbook-pro"
      if $env.LAST_EXIT_CODE != 0 {
        print $"(ansi yellow)⚠ Build had warnings, but may still work(ansi reset)\n"
      } else {
        print $"(ansi green)✓ Build successful(ansi reset)\n"
      }

      print $"(ansi green_bold)✓ Core QA checks passed!(ansi reset)"
    }
  '';

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

        def --env load-secret [secret_name: string, env_var: string] {
          let secret_file = ($secrets_dir | path join $secret_name)
          if ($secret_file | path exists) {
            let secret_value = (open --raw $secret_file | str trim)
            {} | insert $env_var $secret_value | load-env
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
