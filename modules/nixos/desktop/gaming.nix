{ pkgs, ... }: {
  # Gaming configuration module
  # Steam, Proton, Vulkan, Wine, and gaming optimizations

  # Steam with Proton support
  programs.steam = {
    enable = true;
    remotePlay.openFirewall = true;
    dedicatedServer.openFirewall = true;

    # Enable Proton compatibility layer
    extraCompatPackages = with pkgs;
      [
        proton-ge-bin # GloriousEggroll's Proton builds
      ];
  };

  # GameMode for performance optimization
  programs.gamemode = {
    enable = true;
    settings = {
      general = { renice = 10; };
      custom = {
        start = "${pkgs.libnotify}/bin/notify-send 'GameMode started'";
        end = "${pkgs.libnotify}/bin/notify-send 'GameMode ended'";
      };
    };
  };

  # Enable 32-bit graphics support for games
  hardware.graphics = {
    enable = true;
    enable32Bit = true;
  };

  # Gaming-related packages
  environment.systemPackages = with pkgs; [
    # Game launchers
    lutris
    heroic # Epic Games, GOG launcher
    # bottles # Windows app manager

    # Wine for Windows games
    wineWowPackages.stable # Both 32 and 64-bit Wine
    winetricks

    # Performance monitoring
    mangohud # FPS overlay and performance metrics
    # gamescope # Gaming compositor/micro-compositor

    # Proton utilities
    # protonup-qt # Manage Proton versions
    protontricks # Winetricks for Proton games

    # Communication
    discord
    # teamspeak_client

    # Other gaming tools
    # steam-run # Run non-Steam games in Steam runtime
  ];

  # Vulkan support
  environment.variables = {
    # Enable Vulkan validation layers for debugging (optional)
    # VK_LAYER_PATH = "${pkgs.vulkan-validation-layers}/share/vulkan/explicit_layer.d";
  };

  # Kernel parameters for gaming performance (optional, adjust as needed)
  # boot.kernelParams = [
  #   "mitigations=off" # Disable CPU mitigations for performance (less secure)
  # ];

  # Increase file watchers for game modding tools
  boot.kernel.sysctl = { "fs.inotify.max_user_watches" = 524288; };
}
