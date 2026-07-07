{
  pkgs,
  lib,
  username,
  ...
}: {
  imports = [
    ./hardware-configuration.nix
    ../common.nix
    ../../modules/system/hardware/ipu6-camera.nix
    ../../modules/system/scx-schedulers.nix
    ../../modules/profiles/vpn-workstation.nix
    ../../modules/system/hardware/droidcam.nix
  ];

  # NOTE: this host is prepared ahead of the actual hardware arriving.
  # Everything below is a starting point copied from spectre (same 11th-gen
  # Tiger Lake / Iris Xe / IPU6 camera generation) — revisit once the real
  # Compute Element (CPU) and camera sensors are known. In particular:
  #   - nix.settings.cores below assumes a 4-core/8-thread CPU (the common
  #     case across the Celeron 6305..i7-1185G7 Compute Element range) —
  #     check `nproc` after install and adjust.
  #   - hosts/P14E/hardware-configuration.nix is a placeholder; replace it
  #     with the real `nixos-generate-config` output.
  # Deliberately NOT carried over from spectre:
  #   - modules/system/hardware/firmware/vbt.nix — that ships a firmware
  #     blob hand-patched for spectre's exact VBT dump; using it on
  #     different hardware would feed the i915 driver wrong panel data.
  #   - the "hp_wmi" kernel module and the Realtek SD-reader udev rule —
  #     both are HP Spectre-specific hardware.

  programs.steam = {
    enable = true;
    gamescopeSession.enable = true;
    extraPackages = [pkgs.sdl3];
    package = pkgs.steam.override {
      extraArgs = "-system-composer";
    };
  };

  services = {
    # SSH on this host is only reachable over tailscale0 (see security.nix
    # firewall rules), so fail2ban has no public-facing port to protect and
    # would just continuously tail the journal for nothing.
    fail2ban.enable = false;

    printing = {
      enable = true;
      drivers = [pkgs.gutenprint];
    };

    # Smaller journal limit than the common 1G default — laptop SSD.
    journald.extraConfig = ''
      Storage=persistent
      Compress=yes
      SystemMaxUse=500M
      RuntimeMaxUse=100M
    '';

    udev.extraRules = ''
      ACTION=="add", SUBSYSTEM=="leds", RUN+="${pkgs.coreutils}/bin/chgrp video /sys/class/leds/%k/brightness"
      ACTION=="add", SUBSYSTEM=="leds", RUN+="${pkgs.coreutils}/bin/chmod g+w /sys/class/leds/%k/brightness"

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
    crashDump.enable = true;
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
    { device = "/swapfile"; size = 16 * 1024; }
  ];

  systemd.sleep.settings.Sleep = {
    SuspendState = "mem";
    HibernateDelaySec = "90m";
  };

  # Docker — for testing Nextcloud instances
  # Socket-activated: daemon only starts when docker commands are run
  virtualisation.docker = {
    enable = true;
    enableOnBoot = false;
    autoPrune = {
      enable = true;
      dates = "weekly";
    };
  };

  # Limit build parallelism to keep the system responsive.
  # Assumes a 4-core/8-thread CPU (the common case for this Compute Element
  # range) — check `nproc` once installed and adjust.
  nix.settings = {
    cores = 4;
    max-jobs = 2; # Max parallel derivation builds
  };

  users.users.${username}.extraGroups = ["docker"];

  environment.systemPackages = with pkgs; [
    brightnessctl
    dmidecode
    docker-compose
    sbctl
  ];

  system.stateVersion = "24.11";
}
