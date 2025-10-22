{ lib, pkgs, ... }: {
  # QEMU guest agent provides graceful shutdowns and metadata exchange.
  # Disabled by default - enable in host overlay if needed.
  services.qemuGuest.enable = lib.mkDefault false;

  # Spice vdagent handles clipboard sync, display resize, and mouse integration.
  services.spice-vdagentd.enable = lib.mkDefault true;

  # Keep the VM clock in sync if timesyncd is not already enabled elsewhere.
  services.timesyncd.enable = lib.mkDefault true;

  # Ensure essential virtio drivers are available early during boot.
  boot.initrd.kernelModules = lib.mkDefault [
    "virtio_pci"
    "virtio_blk"
    "virtio_net"
    "virtio_scsi"
    "virtio_mmio"
  ];

  boot.kernelModules =
    lib.mkDefault [ "virtio_balloon" "virtio_console" "virtio_rng" ];

  # Provide udev rules to improve virtio device behaviour.
  services.udev.extraRules = lib.mkDefault ''
    ACTION=="add", SUBSYSTEM=="virtio", ATTR{device/driver_override}=""
  '';

  # Pull in a few helper tools useful when tuning the guest.
  environment.systemPackages = with pkgs; [ spice-vdagent ];
}
