{
  lib,
  pkgs,
  user,
  ...
}:
{
  users.users.${user} = {
    isNormalUser = lib.mkDefault true;
    extraGroups = lib.mkDefault [
      "wheel"
      "networkmanager"
      "docker"
    ];
    home = lib.mkDefault "/home/${user}";
    shell = pkgs.fish;
  };

  programs.fish.enable = lib.mkDefault true;
}
