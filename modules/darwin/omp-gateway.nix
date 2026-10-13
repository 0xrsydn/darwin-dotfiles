{
  config,
  inputs,
  lib,
  pkgs,
  user,
  ...
}:
let
  cfg = config.rsydn.ompGateway;
  home = config.users.users.${user}.home;
  configDir = "${home}/.omp-cursor";
  logDir = "${configDir}/logs";
  brokerUrl = "http://127.0.0.1:${toString cfg.brokerPort}";
  gatewayUrl = "http://127.0.0.1:${toString cfg.gatewayPort}/v1";
  omp = lib.getExe cfg.package;
  environment = {
    HOME = home;
    # OMP treats PI_CONFIG_DIR as a directory name relative to HOME.
    PI_CONFIG_DIR = ".omp-cursor";
    PI_CODING_AGENT_DIR = "${configDir}/agent";
    OMP_PROFILE = "";
    PI_PROFILE = "";
    PI_CONFIG_FILES = "";
  };

  cursorLogin = pkgs.writeShellApplication {
    name = "omp-cursor-login";
    runtimeInputs = [ pkgs.coreutils ];
    text = ''
      umask 077
      export HOME=${lib.escapeShellArg home}
      export PI_CONFIG_DIR=.omp-cursor
      export PI_CODING_AGENT_DIR=${lib.escapeShellArg "${configDir}/agent"}
      export OMP_PROFILE="" PI_PROFILE="" PI_CONFIG_FILES=""
      unset OMP_AUTH_BROKER_URL OMP_AUTH_BROKER_TOKEN
      mkdir -p ${lib.escapeShellArg "${configDir}/agent"}
      exec ${omp} auth-broker login cursor
    '';
  };

  broker = pkgs.writeShellScript "omp-auth-broker" ''
    set -eu
    umask 077
    # Use only the dedicated Cursor vault. Never import the default OMP vault.
    unset OMP_AUTH_BROKER_URL OMP_AUTH_BROKER_TOKEN
    exec ${omp} auth-broker serve --bind=127.0.0.1:${toString cfg.brokerPort}
  '';
  gateway = pkgs.writeShellScript "omp-auth-gateway" ''
    set -eu
    umask 077
    # launchd starts agents independently. Wait for the broker to create its key.
    for attempt in $(seq 1 60); do
      [ -s ${lib.escapeShellArg "${configDir}/auth-broker.token"} ] && break
      sleep 1
    done
    if [ ! -s ${lib.escapeShellArg "${configDir}/auth-broker.token"} ]; then
      echo "OMP broker token is missing; check the omp-auth-broker service." >&2
      exit 1
    fi
    export OMP_AUTH_BROKER_URL=${lib.escapeShellArg brokerUrl}
    export OMP_AUTH_BROKER_TOKEN="$(<${lib.escapeShellArg "${configDir}/auth-broker.token"})"
    exec ${omp} auth-gateway serve --bind=127.0.0.1:${toString cfg.gatewayPort}
  '';
  service = command: name: {
    inherit command environment;
    path = [
      pkgs.coreutils
      pkgs.git
      cfg.package
    ];
    serviceConfig = {
      Label = "com.rsydn.${name}";
      RunAtLoad = true;
      KeepAlive = true;
      ThrottleInterval = 10;
      ProcessType = "Background";
      Umask = 63;
      WorkingDirectory = home;
      StandardOutPath = "${logDir}/${name}.log";
      StandardErrorPath = "${logDir}/${name}.error.log";
    };
  };
in
{
  options.rsydn.ompGateway = {
    enable = lib.mkEnableOption "the authenticated Cursor-only OMP broker and gateway" // {
      default = true;
    };
    package = lib.mkOption {
      type = lib.types.package;
      default = inputs.llm-agents.packages.${pkgs.stdenv.hostPlatform.system}.omp;
      description = "OMP package used by both services and Pi model discovery.";
    };
    brokerPort = lib.mkOption {
      type = lib.types.port;
      default = 8765;
      description = "Loopback port for the isolated Cursor credential broker.";
    };
    gatewayPort = lib.mkOption {
      type = lib.types.port;
      default = 4000;
      description = "Loopback port for the Cursor inference gateway.";
    };
  };

  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = cfg.brokerPort != cfg.gatewayPort;
        message = "OMP broker and gateway ports must differ.";
      }
    ];

    # Create private log directories before launchd opens the service log files.
    system.activationScripts.userLaunchd.text = lib.mkBefore ''
      ${pkgs.coreutils}/bin/install -d -m 0700 -o ${lib.escapeShellArg user} \
        ${lib.escapeShellArg configDir} ${lib.escapeShellArg "${configDir}/agent"} ${lib.escapeShellArg logDir}
    '';

    launchd.user.agents = {
      omp-auth-broker = service "${broker}" "omp-auth-broker";
      omp-auth-gateway = service "${gateway}" "omp-auth-gateway";
    };

    home-manager.users.${user}.home = {
      packages = [ cursorLogin ];
      sessionVariables = {
        OMP_GATEWAY_URL = gatewayUrl;
        OMP_GATEWAY_TOKEN_FILE = "${configDir}/auth-gateway.token";
        OMP_GATEWAY_COMMAND = omp;
        OMP_GATEWAY_AGENT_DIR = "${configDir}/agent";
      };
    };
  };
}
