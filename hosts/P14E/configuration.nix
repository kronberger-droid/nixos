_: {
  imports = [
    ./hardware-configuration.nix
    ../common.nix
    ../../modules/profiles/secureboot-laptop.nix
    ../../modules/system/hardware/uvc-camera.nix
    ../../modules/system/hardware/scx-schedulers.nix
    ../../modules/profiles/vpn-workstation.nix
    ../../modules/system/hardware/droidcam.nix
  ];

  # ThinkPad P14E specifics on top of the shared laptop profile. Started as
  # a copy of spectre before the hardware arrived; the hardware config, LUKS
  # layout and SSH key are real now. Still open from that phase:
  # nix.settings.cores below assumes a 4-core/8-thread CPU, check `nproc`
  # and adjust.
  # The webcam is not IPU6. It is a USB UVC module (Foxlink 05c8:03e9) on
  # uvcvideo, hence uvc-camera.nix rather than spectre's ipu6-camera.nix.
  # Deliberately NOT carried over from spectre: vbt.nix (a firmware blob
  # hand-patched for spectre's exact VBT dump; wrong panel data on other
  # hardware), the hp_wmi module and the Realtek SD-reader udev rule.

  boot = {
    # HiDPI panel renders the boot menu at native res, making the generation
    # list tiny. "0" forces the lowest UEFI text mode (80x25) for larger text.
    # Lanzaboote reads this value into loader.conf even with systemd-boot off.
    loader.systemd-boot.consoleMode = "0";
    # Hibernation resume target. The swapfile lives on the LUKS-backed root
    # fs, so resume happens from the unlocked mapper device plus the file's
    # first physical block (from `filefrag -v /swapfile`). If the swapfile is
    # ever recreated (resize, reinstall) this offset must be recomputed.
    # NB: hibernation is only *available* when no process holds secret memory;
    # Electron/Chromium apps do, which disables it kernel-wide while they run.
    resumeDevice = "/dev/mapper/nixos-root";
    kernelParams = [
      "resume_offset=68904960"
      # Disable memfd_secret kernel-wide. Any process holding secret memory
      # (Electron/Chromium apps like Bitwarden do) makes the kernel refuse
      # hibernation, since secretmem pages must never hit disk but a hibernate
      # image writes all of RAM. LUKS-encrypted swap already protects the image
      # at rest, so the trade-off is negligible here.
      "secretmem.enable=0"
    ];
  };

  # Limit build parallelism to keep the system responsive.
  # Assumes a 4-core/8-thread CPU (the common case for this Compute Element
  # range) — check `nproc` once installed and adjust.
  nix.settings = {
    cores = 4;
    max-jobs = 2; # Max parallel derivation builds
  };

  system.stateVersion = "24.11";
}
