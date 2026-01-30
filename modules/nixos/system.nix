{ lib, user, ... }:
{
  imports = [
    ./users.nix
    ./network.nix
    ./ssh.nix
    ./containerization.nix
  ];

  nix = {
    settings.auto-optimise-store = lib.mkDefault true;
    settings.experimental-features = lib.mkDefault [
      "nix-command"
      "flakes"
    ];
    settings.trusted-users = lib.mkDefault [
      "root"
      user
    ];
    optimise.automatic = lib.mkDefault true;
    gc = {
      automatic = lib.mkDefault true;
      dates = lib.mkDefault "weekly";
    };
  };
}
