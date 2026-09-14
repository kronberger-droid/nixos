# Everything spectre and P14E share beyond common.nix: lanzaboote Secure
# Boot with TPM-unlocked LUKS, the laptop peripherals (LED and IIO access,
# printing, QMK), a 16 GB swapfile for hibernation, and the smaller journal.
# The two host files used to carry ~110 identical lines of this and had
# already started to drift (one had the boot editor fixed, one did not).
# Per-host: the resume device and offset, camera module, cores, and any
# vendor-specific quirks (spectre's hp_wmi and SD-reader rule).
{
  pkgs,
  lib,
  ...
}: {
  programs.steam = {
    enable = true;
    gamescopeSession.enable = true;
    extraPackages = [pkgs.sdl3];
    package = pkgs.steam.override {
      extraArgs = "-system-composer";
    };
  };

  services = {
    # SSH on these hosts is only reachable over tailscale0 (see
    # security.nix), so fail2ban has no public-facing port to protect and
    # would just continuously tail the journal for nothing.
    fail2ban.enable = false;

    printing = {
      enable = true;
      drivers = [pkgs.gutenprint];
    };

    # Smaller journal limit than the common 1G default — laptop SSD.
    journald.settings.Journal.SystemMaxUse = "500M";

    udev.extraRules = ''
      ACTION=="add", SUBSYSTEM=="leds", RUN+="${pkgs.uutils-coreutils-noprefix}/bin/chgrp video /sys/class/leds/%k/brightness"
      ACTION=="add", SUBSYSTEM=="leds", RUN+="${pkgs.uutils-coreutils-noprefix}/bin/chmod g+w /sys/class/leds/%k/brightness"

      # Allow access to IIO devices for screen rotation (group-restricted)
      SUBSYSTEM=="iio", KERNEL=="iio:device*", MODE="0660", GROUP="video"
    '';
  };

  hardware = {
    enableRedistributableFirmware = true;
    keyboard.qmk.enable = true;
    graphics.extraPackages = [pkgs.intel-media-driver];
  };

  boot = {
    binfmt.emulatedSystems = ["aarch64-linux"];
    # Lanzaboote replaces systemd-boot for Secure Boot
    systemd-boot-defaults.enable = false;
    loader.systemd-boot.enable = lib.mkForce false;
    loader.efi.canTouchEfiVariables = false;
    # systemd-boot-defaults is off here, so boot-systemd.nix's editor = false
    # never applies; lanzaboote copies this value into loader.conf regardless.
    # With TPM auto-unlock, an editable cmdline (init=/bin/sh) is root on the
    # decrypted disk, which is the one thing Secure Boot exists to stop.
    loader.systemd-boot.editor = false;
    lanzaboote = {
      enable = true;
      pkiBundle = "/var/lib/sbctl";
      configurationLimit = 20;
    };
    kernel.sysctl = {
      # 176 = enable sync (16) + enable remount-ro (32) + enable reboot (128)
      # Allows safe emergency reboot (REISUB) without exposing full sysrq
      "kernel.sysrq" = 176;
    };
    # List option: hosts append their own (P14E's resume_offset, secretmem).
    kernelParams = [
      "nvme_core.default_ps_max_latency_us=0"
      "pcie_aspm=off"
      "snd_intel_dspcfg.dsp_driver=1"
      "intel_iommu=on"
      "console=tty1"
    ];
    blacklistedKernelModules = [
      "iTCO_wdt"
      "watchdog"
    ];
    initrd.luks.devices."nixos-root".crypttabExtraOpts = ["tpm2-device=auto"];
    initrd.systemd.tpm2.enable = true;
  };

  # TPM2 support for Secure Boot + LUKS auto-unlock
  security.tpm2 = {
    enable = true;
    pkcs11.enable = false;
    tctiEnvironment.enable = true;
  };

  swapDevices = [
    {
      device = "/swapfile";
      size = 16 * 1024;
    }
  ];

  environment.systemPackages = with pkgs; [
    brightnessctl
    dmidecode
    sbctl
  ];
}
