{ pkgs, lib, ... }:
let
  inherit (builtins) map toString listToAttrs;

  workspaceNumbers = map toString (lib.range 1 9);

  workspaceFocusBindings = listToAttrs (map (ws: {
    name = "alt-${ws}";
    value = "workspace ${ws}";
  }) workspaceNumbers);

  workspaceSendBindings = listToAttrs (map (ws: {
    name = "alt-shift-${ws}";
    value = "move-node-to-workspace ${ws}";
  }) workspaceNumbers);
in {
  programs.aerospace = {
    enable = true;
    package = pkgs.aerospace;

    launchd = {
      enable = true;
      keepAlive = true;
    };

    userSettings = {
      enable-normalization-flatten-containers = true;
      enable-normalization-opposite-orientation-for-nested-containers = true;
      default-root-container-layout = "tiles";
      default-root-container-orientation = "auto";
      key-mapping.preset = "qwerty";

      gaps = {
        inner = {
          horizontal = 8;
          vertical = 8;
        };
        outer = {
          top = 12;
          bottom = 12;
          left = 12;
          right = 12;
        };
      };

      on-focused-monitor-changed = [ "move-mouse monitor-lazy-center" ];
      on-focus-changed = [ "move-mouse window-lazy-center" ];

      mode = {
        main.binding = {
          "alt-h" = "focus left";
          "alt-j" = "focus down";
          "alt-k" = "focus up";
          "alt-l" = "focus right";

          "alt-shift-h" = "move left";
          "alt-shift-j" = "move down";
          "alt-shift-k" = "move up";
          "alt-shift-l" = "move right";

          "alt-minus" = "resize smart -50";
          "alt-equal" = "resize smart +50";

          "alt-b" = "balance-sizes";
          "alt-slash" = "layout tiles horizontal vertical";
          "alt-comma" = "layout accordion horizontal vertical";
          "alt-space" = "layout floating tiling";

          "alt-enter" = ''exec-and-forget open -na "Ghostty"'';
          "alt-backspace" = "close";

          "alt-tab" = "workspace-back-and-forth";
          "alt-shift-tab" = "move-workspace-to-monitor --wrap-around next";

          "alt-r" = "mode resize";
          "alt-shift-semicolon" = "mode service";
        } // workspaceFocusBindings // workspaceSendBindings;

        resize.binding = {
          h = "resize width -100";
          l = "resize width +100";
          j = "resize height -100";
          k = "resize height +100";
          r = "balance-sizes";
          enter = "mode main";
          esc = "mode main";
        };

        service.binding = {
          esc = [ "reload-config" "mode main" ];
          r = [ "flatten-workspace-tree" "mode main" ];
          f = [ "layout floating tiling" "mode main" ];
          backspace = [ "close-all-windows-but-current" "mode main" ];
          h = [ "join-with left" "mode main" ];
          j = [ "join-with down" "mode main" ];
          k = [ "join-with up" "mode main" ];
          l = [ "join-with right" "mode main" ];
        };
      };
    };
  };
}
