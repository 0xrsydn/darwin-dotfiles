{ lib }:
let
  inherit (builtins) listToAttrs map toString;

  workspaceNumbers = map toString (lib.range 1 9);

  workspaceFocusBindings = listToAttrs (map (ws: {
    name = "alt-${ws}";
    value = "workspace ${ws}";
  }) workspaceNumbers);

  workspaceSendBindings = listToAttrs (map (ws: {
    name = "alt-shift-${ws}";
    value = "move-node-to-workspace ${ws}";
  }) workspaceNumbers);
in { inherit workspaceNumbers workspaceFocusBindings workspaceSendBindings; }
