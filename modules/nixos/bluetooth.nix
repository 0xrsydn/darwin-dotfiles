{ lib, ... }: {
  hardware.bluetooth = {
    enable = lib.mkDefault false; # Enable when needed
    powerOnBoot = lib.mkDefault true;
    settings = {
      General = {
        Enable = "Source,Sink,Media,Socket";
        Experimental = true; # Better codec support
      };
    };
  };
}
