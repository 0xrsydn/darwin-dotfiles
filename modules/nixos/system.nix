{ config, pkgs, lib, user, ... }: {
  users.users.${user} = {
    isNormalUser = lib.mkDefault true;
    extraGroups = lib.mkDefault [ "wheel" "networkmanager" ];
    home = lib.mkDefault "/home/${user}";
    shell = lib.mkDefault pkgs.fish;
  };

  programs.fish.enable = lib.mkDefault true;
}
