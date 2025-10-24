{ pkgs, ... }: {
  # Browser configurations
  home.packages = with pkgs;
    [
      firefox
      # chromium
      # brave
    ];

  # Firefox config (expand as needed)
  # programs.firefox = {
  #   enable = true;
  #   profiles.default = {
  #     settings = {
  #       "browser.startup.homepage" = "about:home";
  #     };
  #   };
  # };
}
