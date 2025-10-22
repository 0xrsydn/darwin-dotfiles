{ lib, ... }: {
  imports = [ ./users.nix ./network.nix ./ssh.nix ./containerization.nix ];

  nix = {
    settings.auto-optimise-store = lib.mkDefault true;
    optimise.automatic = lib.mkDefault true;
    gc = {
      automatic = lib.mkDefault true;
      dates = lib.mkDefault "weekly";
    };
  };
}
