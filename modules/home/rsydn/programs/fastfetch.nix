{ config, lib, pkgs, ... }:

{
  home.packages = [ pkgs.fastfetch ];

  # Copy the custom logo file
  xdg.configFile."fastfetch/oguri-logo.txt".source = ./fastfetch/oguri-logo.txt;

  xdg.configFile."fastfetch/config.jsonc".text = builtins.toJSON {
    "$schema" =
      "https://github.com/fastfetch-cli/fastfetch/raw/dev/doc/json_schema.json";

    logo = {
      type = "file";
      source = "~/.config/fastfetch/oguri-logo.txt";
      padding = {
        top = 2;
        right = 6;
        left = 2;
      };
    };

    display = { separator = " → "; };

    modules = [
      "break"

      # Hardware Section
      {
        type = "custom";
        format = "\\u001b[90m┌──────────────────────Hardware──────────────────────┐";
      }
      {
        type = "host";
        key = " PC";
        keyColor = "green";
      }
      {
        type = "cpu";
        key = "│ ├";
        showPeCoreCount = true;
        keyColor = "green";
      }
      {
        type = "gpu";
        key = "│ ├";
        detectionMethod = "pci";
        keyColor = "green";
      }
      {
        type = "display";
        key = "│ ├󱄄";
        keyColor = "green";
      }
      {
        type = "disk";
        key = "│ ├󰋊";
        keyColor = "green";
      }
      {
        type = "memory";
        key = "│ ├";
        keyColor = "green";
      }
      {
        type = "swap";
        key = "└ └󰓡 ";
        keyColor = "green";
      }
      {
        type = "custom";
        format = "\\u001b[90m└────────────────────────────────────────────────────┘";
      }
      "break"

      # Software Section
      {
        type = "custom";
        format = "\\u001b[90m┌──────────────────────Software──────────────────────┐";
      }
      {
        type = "os";
        key = " OS";
        keyColor = "blue";
      }
      {
        type = "kernel";
        key = "│ ├";
        keyColor = "blue";
      }
      {
        type = "wm";
        key = "│ ├";
        keyColor = "blue";
      }
      {
        type = "de";
        key = " DE";
        keyColor = "blue";
      }
      {
        type = "terminal";
        key = "│ ├";
        keyColor = "blue";
      }
      {
        type = "shell";
        key = "│ ├";
        keyColor = "blue";
      }
      {
        type = "packages";
        key = "│ ├󰏖";
        keyColor = "blue";
      }
      {
        type = "wmtheme";
        key = "│ ├󰉼";
        keyColor = "blue";
      }
      {
        type = "terminalfont";
        key = "└ └";
        keyColor = "blue";
      }
      {
        type = "custom";
        format = "\\u001b[90m└────────────────────────────────────────────────────┘";
      }
      "break"

      # Uptime / Age Section
      {
        type = "custom";
        format = "\\u001b[90m┌────────────────────Uptime / Age────────────────────┐";
      }
      {
        type = "command";
        key = "󱦟 OS Age";
        keyColor = "magenta";
        # macOS compatible stat command
        text = "if [ $(uname) = 'Darwin' ]; then birth=$(stat -f %B /); else birth=$(stat -c %W /); fi; current=$(date +%s); days=$(( (current - birth) / 86400 )); echo \"$days days\"";
      }
      {
        type = "uptime";
        key = "󱫐 Uptime";
        keyColor = "magenta";
      }
      {
        type = "custom";
        format = "\\u001b[90m└────────────────────────────────────────────────────┘";
      }
      "break"
    ];
  };
}
