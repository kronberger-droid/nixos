_: {
  imports = [
    ./hardware-configuration.nix
    ../common.nix
    ../../modules/profiles/secureboot-laptop.nix
    ../../modules/system/hardware/uvc-camera.nix
    ../../modules/system/hardware/tpbridge-touchpad.nix
    ../../modules/system/hardware/scx-schedulers.nix
    ../../modules/profiles/vpn-workstation.nix
    ../../modules/system/hardware/droidcam.nix
  ];

  # ThinkPad P14E specifics on top of the shared laptop profile. Started as
  # a copy of spectre before the hardware arrived; the hardware config, LUKS
  # layout and SSH key are real now.
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
    # secretmem.enable=0 comes from power-management.nix, which adds it on
    # every host that can hibernate.
    kernelParams = ["resume_offset=68904960"];
  };

  # Steam runs as an X11 client through xwayland-satellite, which hands it no
  # output scale, and its own "Scale text and icons" setting skips popups,
  # menus and dialogs. This forces the scale on every Steam window. 1.75
  # matches the AOC, which every shikane profile on this host drives at 1.75;
  # on the 2.0 panel Steam comes out a bit small.
  environment.sessionVariables.STEAM_FORCE_DESKTOPUI_SCALING = "1.75";

  # Off NetworkManager: iwd does wifi, networkd ethernet. See
  # modules/system/networking/iwd.nix for the stages.
  networking.iwdSwap.stage = "standalone";

  # Limit build parallelism to keep the system responsive. The i7-1185G7 is
  # 4 cores / 8 threads (`nproc` = 8), so one build gets half the threads.
  nix.settings = {
    cores = 4;
    max-jobs = 2; # Max parallel derivation builds
  };

  system.stateVersion = "26.11";
}
