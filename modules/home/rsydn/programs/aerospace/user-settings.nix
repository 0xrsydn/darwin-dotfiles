{ modes }:
{
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

  mode = modes;
}
