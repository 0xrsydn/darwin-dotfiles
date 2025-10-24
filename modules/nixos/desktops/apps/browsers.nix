{ pkgs, user, ... }: {
  # Browser configurations for desktop users

  home-manager.users.${user} = {
    # User packages: Browsers
    home.packages = with pkgs; [ brave ];
  };
}
