{ lib, pkgs, ... }: {
  # Hardware acceleration (OpenGL/Vulkan)
  hardware.graphics = {
    enable = lib.mkDefault true;
    enable32Bit = lib.mkDefault true; # For 32-bit games/apps

    extraPackages = with pkgs; [
      # Common drivers (expand based on your hardware)
      mesa
      vulkan-validation-layers
      vulkan-tools

      # Intel-specific (comment out if not using Intel)
      intel-media-driver
      intel-vaapi-driver

      # AMD-specific (comment out if not using AMD)
      # rocmPackages.clr.icd
    ];
  };
}
