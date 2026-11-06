# Mac side of the work VM (hosts/work-vm). Both commands use the VM's SOCKS
# proxy, so company traffic goes through its Cloudflare One tunnel and
# personal traffic does not:
# - work-browser: a separate Brave profile
# - work-proxy <command>: one CLI command with proxy variables set
{
  config,
  lib,
  pkgs,
  ...
}:
let
  inherit (lib)
    mkEnableOption
    mkIf
    mkOption
    types
    ;
  cfg = config.rsydn.workAccess;

  proxyAddress = "${cfg.proxyHost}:${toString cfg.proxyPort}";

  workBrowser = pkgs.writeShellScriptBin "work-browser" ''
    exec /usr/bin/open -na "Brave Browser" --args \
      --user-data-dir="$HOME/.local/share/brave-work" \
      --proxy-server="socks5://${proxyAddress}" \
      "$@"
  '';

  # Run one command with its traffic sent through the work VM. socks5h makes
  # the VM resolve DNS, so internal hostnames work.
  workProxy = pkgs.writeShellScriptBin "work-proxy" ''
    if [ "$#" -eq 0 ]; then
      echo "usage: work-proxy <command> [args...]" >&2
      exit 64
    fi
    proxy="socks5h://${proxyAddress}"
    export ALL_PROXY="$proxy" all_proxy="$proxy"
    export HTTPS_PROXY="$proxy" https_proxy="$proxy"
    export HTTP_PROXY="$proxy" http_proxy="$proxy"
    export NO_PROXY="localhost,127.0.0.1,::1,.orb.local" no_proxy="localhost,127.0.0.1,::1,.orb.local"
    exec "$@"
  '';
in
{
  options.rsydn.workAccess = {
    enable = mkEnableOption "the work-browser command for reaching company sites through the work VM";

    proxyHost = mkOption {
      type = types.str;
      default = "work-vm.orb.local";
      description = "Host of the SOCKS5 proxy running in the work VM.";
    };

    proxyPort = mkOption {
      type = types.port;
      default = 1080;
      description = "Port of the SOCKS5 proxy running in the work VM.";
    };
  };

  config = mkIf cfg.enable {
    environment.systemPackages = [
      workBrowser
      workProxy
    ];
  };
}
