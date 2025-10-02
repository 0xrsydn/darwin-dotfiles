{ workspaceFocusBindings, workspaceSendBindings }: {
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
}
