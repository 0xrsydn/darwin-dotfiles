# Work VM: a NixOS machine in OrbStack on the MacBook. The Cloudflare One
# client, Docker, and work repos live here so company traffic and code stay
# off macOS. Deploy from the Mac:
#   orb -m work-vm nixos-rebuild switch --sudo --flake ~/Development/dotfiles#work-vm
{
  lib,
  modulesPath,
  user,
  ...
}:
{
  imports = [
    "${modulesPath}/virtualisation/lxc-container.nix"
    ./orbstack.nix
  ];

  networking.hostName = "work-vm";
  time.timeZone = "Asia/Jakarta";
  # Release OrbStack installed the machine with; do not bump.
  system.stateVersion = "25.11";

  # OrbStack maps the Mac user into the machine with the Mac's uid (501).
  # A uid below 1000 rules out isNormalUser, so simulate it as OrbStack does.
  users.mutableUsers = false;
  users.users.${user} = {
    uid = 501;
    isNormalUser = lib.mkForce false;
    isSystemUser = true;
    group = "users";
    createHome = true;
    home = "/home/${user}";
    homeMode = "700";
    extraGroups = [
      "wheel"
      "orbstack"
      "audio"
      "docker"
    ];
  };
  security.sudo.wheelNeedsPassword = false;

  # OrbStack provides networking through systemd-networkd on eth0.
  networking = {
    dhcpcd.enable = false;
    useDHCP = false;
    useHostResolvConf = false;
    networkmanager.enable = false;
  };
  systemd.network = {
    enable = true;
    networks."50-eth0" = {
      matchConfig.Name = "eth0";
      networkConfig = {
        DHCP = "ipv4";
        IPv6AcceptRA = true;
      };
      linkConfig.RequiredForOnline = "routable";
    };
  };

  # Tailscale stays on the Mac. Running it here would fight the Cloudflare One
  # client for routes and DNS.
  services.tailscale.enable = false;

  # Cloudflare One (WARP) client. Enroll once, inside the VM:
  #   warp-cli registration new <team-name>
  # then finish the browser login on the Mac (see hosts/work-vm/README.md).
  services.cloudflare-warp.enable = true;

  # If the company turns on Gateway TLS inspection, trust its root certificate:
  # security.pki.certificateFiles = [ ./cloudflare-gateway-ca.pem ];

  # OrbStack's local development CA, copied from the generated configuration.
  security.pki.certificates = [
    ''
      -----BEGIN CERTIFICATE-----
      MIICDDCCAbKgAwIBAgIQaen0JWx4o88cLDyl7cV+QDAKBggqhkjOPQQDAjBmMR0w
      GwYDVQQKExRPcmJTdGFjayBEZXZlbG9wbWVudDEeMBwGA1UECwwVQ29udGFpbmVy
      cyAmIFNlcnZpY2VzMSUwIwYDVQQDExxPcmJTdGFjayBEZXZlbG9wbWVudCBSb290
      IENBMB4XDTI1MTExMDA0MTgxNVoXDTM1MTExMDA0MTgxNVowZjEdMBsGA1UEChMU
      T3JiU3RhY2sgRGV2ZWxvcG1lbnQxHjAcBgNVBAsMFUNvbnRhaW5lcnMgJiBTZXJ2
      aWNlczElMCMGA1UEAxMcT3JiU3RhY2sgRGV2ZWxvcG1lbnQgUm9vdCBDQTBZMBMG
      ByqGSM49AgEGCCqGSM49AwEHA0IABJX4zN35OmvunIIbZFyXzrV3qG6uCRSwiizB
      vLR8lcamiwk2QPvHRbJ+F/MC0GOTvchTGuzxlKaSZX9AZj3MbHmjQjBAMA4GA1Ud
      DwEB/wQEAwIBBjAPBgNVHRMBAf8EBTADAQH/MB0GA1UdDgQWBBRR4efM9WlqNhxj
      yI1Afpipv77b8TAKBggqhkjOPQQDAgNIADBFAiEA5DQUuKG+QsVutOhbNy+vWlHR
      o4AkMLbUPEm8b+g5q7ICIFByJ/Fkdilvg9a2l5IKifYwrOfFhvyJKpdN8kntXTca
      -----END CERTIFICATE-----
    ''
  ];

  # SOCKS5 proxy so the Mac reaches company sites through this VM's tunnel:
  # socks5h://work-vm.orb.local:1080 (work-browser, work-proxy, ssh).
  services.microsocks = {
    enable = true;
    ip = "::";
    port = 1080;
  };

  # Only the Mac may use the proxy. OrbStack NATs the Mac's connections to
  # 192.168.139.3, while its Docker engine (every container on the Mac)
  # arrives from 192.168.139.2 and must not reach the company network here.
  # Chromium cannot send SOCKS passwords, so a source rule replaces auth.
  networking.firewall.extraCommands = ''
    iptables -A nixos-fw -p tcp -s 192.168.139.3 --dport 1080 -j nixos-fw-accept
  '';

  # Run prebuilt binaries that company repos and editors download (npm and pip
  # wheels with native code, VS Code and Cursor remote servers).
  programs.nix-ld.enable = true;

  # Docker instead of Podman, so company compose files run unchanged and image
  # pulls go through the tunnel.
  rsydn.containerization = {
    podman.enable = false;
    docker.enable = true;
  };

  # Both the shared module and the container profile set this with mkDefault.
  # Store optimisation stays off inside the container.
  nix.optimise.automatic = false;

  # Same binary cache as the Mac, for llm-agents.nix packages.
  nix.settings = {
    extra-substituters = [ "https://cache.numtide.com" ];
    extra-trusted-public-keys = [ "niks3.numtide.com-1:DTx8wZduET09hRmMtKdQDxNNthLQETkc/yaX7M4qK0g=" ];
  };
}
