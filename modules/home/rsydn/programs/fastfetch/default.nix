{ config, lib, pkgs, ... }:

{
  home.packages = [ pkgs.fastfetch ];

  # Copy the custom logo file
  xdg.configFile."fastfetch/oguri-logo.txt".source = ./oguri-logo.txt;

  xdg.configFile."fastfetch/config.jsonc".text =
    let esc = builtins.fromJSON ''"\u001b"'';
    in builtins.toJSON {
      "$schema" =
        "https://github.com/fastfetch-cli/fastfetch/raw/dev/doc/json_schema.json";

      logo = {
        type = "file";
        source = "~/.config/fastfetch/oguri-logo.txt";
        color."1" = "green";
        padding = {
          top = 2;
          right = 6;
          left = 2;
        };
      };

      display = {
        separator = " → ";
        key = { width = 16; };
      };

      modules = [
        "break"

        # Hardware Section
        {
          type = "custom";
          format =
            "${esc}[32m── Hardware──────────────────────────────────────────${esc}[0m";
        }
        {
          type = "host";
          key = " PC";
          keyColor = "green";
        }
        {
          type = "cpu";
          key = " CPU";
          showPeCoreCount = true;
          keyColor = "green";
        }
        {
          type = "gpu";
          key = " GPU";
          detectionMethod = "pci";
          keyColor = "green";
        }
        {
          type = "display";
          key = "󱄄 Display";
          keyColor = "green";
        }
        {
          type = "disk";
          key = "󰋊 Disk";
          keyColor = "green";
        }
        {
          type = "memory";
          key = " Memory";
          keyColor = "green";
        }
        {
          type = "swap";
          key = "󰓡 Swap";
          keyColor = "green";
        }
        "break"

        # Software Section
        {
          type = "custom";
          format =
            "${esc}[34m── Software──────────────────────────────────────────${esc}[0m";
        }
        {
          type = "os";
          key = " OS";
          keyColor = "blue";
        }
        {
          type = "command";
          key = "󰘬 Branch";
          keyColor = "blue";
          text = ''branch=$(git -C ~/Development/dotfiles branch --show-current 2>/dev/null || echo "unknown"); echo "$branch"'';
        }
        {
          type = "kernel";
          key = " Kernel";
          keyColor = "blue";
        }
        {
          type = "wm";
          key = " WM";
          keyColor = "blue";
        }
        {
          type = "de";
          key = " DE";
          keyColor = "blue";
        }
        {
          type = "terminal";
          key = " Terminal";
          keyColor = "blue";
        }
        {
          type = "packages";
          key = "󰏖 Packages";
          keyColor = "blue";
        }
        {
          type = "wmtheme";
          key = "󰉼 WM Theme";
          keyColor = "blue";
        }
        {
          type = "terminalfont";
          key = " Terminal Font";
          keyColor = "blue";
        }
        "break"

        # Uptime / Age Section
        {
          type = "custom";
          format =
            "${esc}[35m── Uptime / Age─────────────────────────────────────${esc}[0m";
        }
        {
          type = "command";
          key = "󱦟 OS Age";
          keyColor = "magenta";
          # macOS compatible stat command
          text = ''
            if [ $(uname) = 'Darwin' ]; then birth=$(stat -f %B /); else birth=$(stat -c %W /); fi; current=$(date +%s); days=$(( (current - birth) / 86400 )); echo "$days days"'';
        }
        {
          type = "uptime";
          key = "󱫐 Uptime";
          keyColor = "magenta";
        }
        "break"
      ];
    };
}
