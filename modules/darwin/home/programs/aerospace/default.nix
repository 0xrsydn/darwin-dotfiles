{ pkgs, lib, ... }:
let
  workspaceHelpers = import ./workspaces.nix { inherit lib; };

  modes = import ./modes.nix {
    inherit (workspaceHelpers) workspaceFocusBindings workspaceSendBindings;
  };

  userSettings = import ./user-settings.nix { modes = modes; };
in {
  programs.aerospace = {
    enable = true;
    package = pkgs.aerospace;

    launchd = {
      enable = true;
      keepAlive = true;
    };

    userSettings = userSettings;
  };
}
