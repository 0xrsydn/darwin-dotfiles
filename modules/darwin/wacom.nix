# Keeps the Wacom CTH-480 (Intuos Pen & Touch Small) on the last driver that
# supports it. Driver 6.4.x and later report this tablet as "no longer
# supported", and Wacom's updater would move the system onto one of them.
#
# On every activation this module:
# - installs the pinned driver (from a hash-checked DMG) when it is missing or
#   a different version is installed, removing the other version first
# - turns off Wacom's root update daemon, so the driver is not updated
#
# It cannot grant the Accessibility / Input Monitoring permissions the driver
# needs; approve those once in System Settings after a fresh install.
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
  cfg = config.rsydn.wacom;

  appDir = "/Applications/Wacom Tablet.localized";
  driverInfoPlist = "${appDir}/.Tablet/WacomTabletDriver.app/Contents/Info.plist";
  tabletUtility = "${appDir}/Wacom Tablet Utility.app/Contents/MacOS/Wacom Tablet Utility";
  updateDaemon = "com.wacom.UpdateHelper";
in
{
  options.rsydn.wacom = {
    enable = mkEnableOption "the pinned legacy Wacom tablet driver";

    version = mkOption {
      type = types.str;
      default = "6.3.46-2";
      description = "Driver version to keep installed. Must match the version string the driver reports.";
    };

    dmg = mkOption {
      type = types.package;
      default = pkgs.fetchurl {
        url = "https://cdn.wacom.com/u/productsupport/drivers/mac/professional/WacomTablet_6.3.46-2.dmg";
        hash = "sha256-zT8RNNchE5+T+AkDmgI4wkhBJzDMIEid/liPkIDqgrA=";
      };
      defaultText = lib.literalExpression "Wacom's 6.3.46-2 driver DMG";
      description = "Driver disk image holding `Install Wacom Tablet.pkg`. Change it together with `version`.";
    };

    disableUpdater = mkOption {
      type = types.bool;
      default = true;
      description = "Turn off Wacom's root update daemon so it cannot install a newer driver.";
    };
  };

  config = mkIf cfg.enable {
    system.activationScripts.postActivation.text = lib.mkAfter ''
      echo "checking Wacom tablet driver..." >&2

      wacom_installed=""
      if [ -f ${lib.escapeShellArg driverInfoPlist} ]; then
        wacom_installed=$(
          /usr/bin/defaults read ${lib.escapeShellArg driverInfoPlist} CFBundleShortVersionString 2>/dev/null \
            | /usr/bin/sed 's/^Wacom Tablet //' \
            || true
        )
      fi

      if [ "$wacom_installed" != ${lib.escapeShellArg cfg.version} ]; then
        if [ -n "$wacom_installed" ]; then
          echo "removing Wacom driver $wacom_installed (want ${cfg.version})..." >&2
          ${lib.escapeShellArg tabletUtility} --uninstall || true
          # Left behind by the 6.4.x uninstaller.
          rm -rf /Library/PrivilegedHelperTools/Wacom_IOManager.app \
            "/Library/DCV Extensions/WacomADCV.json"
          /usr/sbin/pkgutil --forget com.wacom.TabletInstaller >/dev/null 2>&1 || true
        fi

        echo "installing Wacom driver ${cfg.version}..." >&2
        wacom_mount=$(/usr/bin/mktemp -d /tmp/wacom-driver.XXXXXX)
        if /usr/bin/hdiutil attach -nobrowse -readonly -quiet \
          -mountpoint "$wacom_mount" ${cfg.dmg}; then
          /usr/sbin/installer -pkg "$wacom_mount/Install Wacom Tablet.pkg" -target / \
            || echo "warning: Wacom driver install failed" >&2
          /usr/bin/hdiutil detach -quiet "$wacom_mount" || true
        else
          echo "warning: could not mount Wacom driver image" >&2
        fi
        rmdir "$wacom_mount" 2>/dev/null || true
      fi

      ${lib.optionalString cfg.disableUpdater ''
        # `disable` persists in launchd's override database, so the daemon
        # stays off even if a reinstall puts its plist back.
        /bin/launchctl disable system/${updateDaemon}
        /bin/launchctl bootout system/${updateDaemon} 2>/dev/null || true
      ''}
    '';
  };
}
