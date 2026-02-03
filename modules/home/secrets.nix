{
  config,
  lib,
  inputs,
  ...
}:
let
  inherit (lib)
    mkEnableOption
    mkOption
    mkIf
    types
    ;
  cfg = config.rsydn.secrets;

  sanitizeSecret =
    name: secret:
    let
      sopsFile = secret.sopsFile or cfg.defaultSopsFile;
      extra = lib.filterAttrs (
        k: _:
        !(builtins.elem k [
          "path"
          "mode"
          "sopsFile"
        ])
      ) secret;
    in
    {
      path = secret.path or "${config.xdg.configHome}/secrets/${name}";
      mode = secret.mode or "0400";
    }
    // (lib.optionalAttrs (sopsFile != null) { inherit sopsFile; })
    // extra;
in
{
  imports = [ inputs.sops-nix.homeManagerModules.sops ];

  options.rsydn.secrets = {
    enable = mkEnableOption "sops-nix integration for managing decrypted secrets";

    ageKeyFile = mkOption {
      type = types.str;
      default = "${config.home.homeDirectory}/.config/sops/age/keys.txt";
      description = "Path to the Age key used for decrypting secrets.";
    };

    defaultSopsFile = mkOption {
      type = types.nullOr types.path;
      default = null;
      description = "Optional default SOPS file used when a secret definition omits `sopsFile`.";
    };

    secrets = mkOption {
      type = types.attrsOf types.attrs;
      default = { };
      description = "Secret entries forwarded to `sops.secrets` with sensible defaults.";
      example = lib.literalExpression ''
        {
          "api-key" = {
            sopsFile = ./secrets.yaml;
            path = "${config.xdg.configHome}/secrets/api-key";
            mode = "0400";
          };
        }
      '';
    };
  };

  config = mkIf cfg.enable {
    sops = {
      age = {
        keyFile = cfg.ageKeyFile;
        generateKey = true;
      };

      # Ensure the LaunchAgent on macOS can find `getconf` (needed by
      # sops-install-secrets to resolve DARWIN_USER_TEMP_DIR).
      # Without this, age.plugins produces an empty PATH.
      environment.PATH = lib.mkForce "/usr/bin";

      secrets = lib.mapAttrs sanitizeSecret cfg.secrets;
    }
    // (lib.optionalAttrs (cfg.defaultSopsFile != null) {
      defaultSopsFile = cfg.defaultSopsFile;
    });

    home.activation.ensureSecretDir = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
      mkdir -p "${config.xdg.configHome}/secrets"
      chmod 700 "${config.xdg.configHome}/secrets"
    '';
  };
}
