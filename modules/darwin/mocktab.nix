# MockTab: open-source macOS driver for Wacom tablets that Wacom no longer
# supports (here the Intuos Pen & Touch CTH-480). https://mocktab.org
#
# Installs MockTab.app from a hash-checked DMG only when it is missing. An
# installed copy is never replaced: MockTab updates itself, and replacing the
# app makes macOS drop its Accessibility / Input Monitoring permissions.
#
# Grant those two permissions once in System Settings after a fresh install,
# then relaunch MockTab and replug the tablet.
{
  config,
  lib,
  pkgs,
  ...
}:
let
  inherit (lib)
    mkEnableOption
    mkIf
    mkOption
    types
    ;
  cfg = config.rsydn.mocktab;
  appPath = "/Applications/MockTab.app";
in
{
  options.rsydn.mocktab = {
    enable = mkEnableOption "the MockTab tablet driver";

    dmg = mkOption {
      type = types.package;
      default = pkgs.fetchurl {
        url = "https://github.com/Cyzor/tablet-driver/releases/download/v0.6.1/MockTab-0.6.1.dmg";
        hash = "sha256-OgqR2wxIgvmRcuODgZTEosSJAPiHMqGVzG/vee2GBww=";
      };
      defaultText = lib.literalExpression "MockTab 0.6.1 DMG";
      description = "Disk image holding MockTab.app, used only when the app is not installed.";
    };
  };

  config = mkIf cfg.enable {
    assertions = [
      {
        assertion = !(config.rsydn.wacom.enable or false);
        message = "rsydn.mocktab and rsydn.wacom both drive the tablet; enable only one.";
      }
    ];

    system.activationScripts.postActivation.text = lib.mkAfter ''
      if [ ! -d ${lib.escapeShellArg appPath} ]; then
        echo "installing MockTab..." >&2
        mocktab_mount=$(/usr/bin/mktemp -d /tmp/mocktab.XXXXXX)
        if /usr/bin/hdiutil attach -nobrowse -readonly -quiet \
          -mountpoint "$mocktab_mount" ${cfg.dmg}; then
          /usr/bin/ditto "$mocktab_mount/MockTab.app" ${lib.escapeShellArg appPath} \
            || echo "warning: copying MockTab failed" >&2
          /usr/bin/hdiutil detach -quiet "$mocktab_mount" || true
        else
          echo "warning: could not mount MockTab image" >&2
        fi
        rmdir "$mocktab_mount" 2>/dev/null || true
      fi
    '';
  };
}
