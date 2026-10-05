{
  inputs,
  pkgs,
  lib,
  config,
  ...
}:
let
  cfg = config.services.kache;

  # launchd agents do not inherit the user shell environment, so the daemon
  # would miss the sops-decrypted KACHE_S3_* credentials. This wrapper loads
  # them from the runtime secret files, then execs the real daemon.
  # Values are read at activation/runtime only - never baked into the store.
  kacheDaemonWrapper = pkgs.writeShellScript "kache-daemon-wrapper" ''
    secret_dir="''${XDG_CONFIG_HOME:-$HOME/.config}/secrets/global-env"

    for secret_file in "$secret_dir"/KACHE_S3_*; do
      [ -e "$secret_file" ] || continue
      name="$(basename "$secret_file")"
      case "$name" in
        *[!A-Za-z0-9_]*) continue ;;
      esac
      export "$name=$(<"$secret_file")"
    done

    exec ${lib.getExe cfg.package} daemon run
  '';
in
{
  imports = [ inputs.kache.darwinModules.default ];

  services.kache = {
    enable = true;
    daemon.enable = true;

    settings.cache.remote = {
      type = "s3";
      bucket = "kache-build-cache";
      endpoint = "https://bb8d9158f0640a3d950d2597f52e9104.r2.cloudflarestorage.com";
      region = "auto";
    };
  };

  # Point the upstream module's launchd agent at the credential wrapper.
  launchd.user.agents.kache.serviceConfig.ProgramArguments = lib.mkForce [
    "${kacheDaemonWrapper}"
  ];
}
