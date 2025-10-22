{ lib, ... }: {
  services.openssh = {
    enable = lib.mkDefault true;
    openFirewall = lib.mkDefault true;
    settings = {
      PermitRootLogin = "no";
      PasswordAuthentication = false;
    };
  };

  # Run tailscale so the VM can be reached over the mesh network for SSH.
  services.tailscale = {
    enable = lib.mkDefault true;
    useRoutingFeatures = lib.mkDefault "client";
    extraUpFlags = lib.mkDefault [ "--ssh" ];
  };
}
