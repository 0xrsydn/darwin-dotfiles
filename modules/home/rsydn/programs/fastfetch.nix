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
        top = 1;
        right = 2;
      };
    };

    display = {
      separator = " → ";
      color = {
        keys = "cyan";
        title = "blue";
      };
    };

    modules = [
      {
        type = "title";
        format = "{user-name}@{host-name}";
      }
      {
        type = "separator";
        string = "─";
      }
      {
        type = "os";
        key = "OS";
        keyColor = "cyan";
      }
      {
        type = "kernel";
        key = "Kernel";
      }
      {
        type = "uptime";
        key = "Uptime";
      }
      {
        type = "packages";
        key = "Packages";
      }
      {
        type = "shell";
        key = "Shell";
      }
      {
        type = "display";
        key = "Display";
        compactType = "scaled";
      }
      {
        type = "de";
        key = "DE";
      }
      {
        type = "wm";
        key = "WM";
      }
      {
        type = "terminal";
        key = "Terminal";
      }
      {
        type = "terminalfont";
        key = "Font";
      }
      {
        type = "cpu";
        key = "CPU";
        temp = true;
      }
      {
        type = "gpu";
        key = "GPU";
        temp = true;
      }
      {
        type = "memory";
        key = "Memory";
      }
      {
        type = "disk";
        key = "Disk (/)";
        folders = "/";
      }
      {
        type = "separator";
        string = "─";
      }
      {
        type = "colors";
        paddingLeft = 2;
        symbol = "circle";
      }
    ];
  };
}
