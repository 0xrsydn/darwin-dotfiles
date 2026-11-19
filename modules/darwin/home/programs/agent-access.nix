# Bitwarden Agent Access, Mac (listener) side: `aac` and `bw`.
# Agents on hermes-vm request credentials; this Mac approves them.
# Setup and trust model: docs/services/agent-access.md in personal-clan-nix.
#
# `aac` comes from the clan repo, built with its own pinned nixpkgs and with our
# relay as the default. Its wrapper appends bitwarden-cli to PATH, so the `bw`
# installed here (for `bw config` and `bw login`) is the one `aac` runs. Take
# it from the clan's nixpkgs so both are the same version.
#
# At login, a launchd agent starts the listener in tmux session `aac` unless
# one already exists. The vault stays locked: attach with `tmux attach -t aac`
# and type `/unlock` after every start. Nothing secret passes through here.
{
  config,
  pkgs,
  inputs,
  ...
}:
let
  system = pkgs.stdenv.hostPlatform.system;
  clan = inputs.personal-clan;
  agentAccess = clan.packages.${system}.agent-access;
  bitwardenCli = clan.inputs.nixpkgs.legacyPackages.${system}.bitwarden-cli;
  tmux = "${config.programs.tmux.package}/bin/tmux";

  # Same tmux as the shell's, so `tmux attach -t aac` talks to this server.
  # Waits for the relay (Tailscale may not be up yet at login) before starting.
  startListener = pkgs.writeShellScript "aac-listen-tmux" ''
    if ${tmux} has-session -t aac 2>/dev/null; then
      echo "tmux session aac already exists"
      exit 0
    fi

    for _ in $(seq 60); do
      /usr/bin/nc -z -G 2 greencloud-vps.tail2b4d49.ts.net 8095 2>/dev/null && break
      sleep 2
    done

    exec ${tmux} new-session -d -s aac '${agentAccess}/bin/aac listen --reusable-psk'
  '';
in
{
  home.packages = [
    agentAccess
    bitwardenCli
  ];

  launchd.agents.aac-listen = {
    enable = true;
    config = {
      ProgramArguments = [ "${startListener}" ];
      RunAtLoad = true;
      KeepAlive = false;
      ProcessType = "Interactive";
      EnvironmentVariables.PATH = "/etc/profiles/per-user/${config.home.username}/bin:/run/current-system/sw/bin:/usr/bin:/bin";
      StandardOutPath = "${config.home.homeDirectory}/Library/Logs/aac-listen-tmux.log";
      StandardErrorPath = "${config.home.homeDirectory}/Library/Logs/aac-listen-tmux.log";
    };
  };
}
