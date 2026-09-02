{
  config,
  pkgs,
  lib,
  ...
}:
let
  globalEnvironmentSecretNames = [
    "ANTHROPIC_API_KEY"
    "BRAVE_SEARCH_API_KEY"
    "CROF_API_KEY"
    "EXA_API_KEY"
    "FAL_API_KEY"
    "FIRECRAWL_API_KEY"
    "GROQ_API_KEY"
    "KIMI_API_KEY"
    "MOONSHOT_API_KEY"
    "OPENAI_API_KEY"
    "OPENROUTER_API_KEY"
    "ZAI_API_KEY"
  ];
in
{
  # Import shared cross-platform home configuration
  imports = [
    ../../home/base.nix
    ../../home/shell/nushell.nix
    ../../home/shell/zsh.nix
    ./programs/aerospace
    ./programs/kitty.nix
  ];

  # Decrypt each global environment variable to a separate runtime file.
  # Zsh and Nushell load the files without evaluating shell source text.
  rsydn.secrets = {
    enable = lib.mkDefault true;
    defaultSopsFile = ../../../secrets/global-env.sops.yaml;
    secrets = lib.genAttrs globalEnvironmentSecretNames (name: {
      format = "yaml";
      key = name;
      path = "${config.xdg.configHome}/secrets/global-env/${name}";
    });
  };

  home.activation.ensureGlobalEnvironmentSecretDir =
    lib.hm.dag.entryBetween [ "sops-nix" ] [ "writeBoundary" ]
      ''
        rm -f "${config.xdg.configHome}/secrets/global-env.yaml"
        mkdir -p "${config.xdg.configHome}/secrets/global-env"
        chmod 700 "${config.xdg.configHome}/secrets/global-env"
      '';
}
