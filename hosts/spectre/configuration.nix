{
  pkgs,
  lib,
  config,
  ...
}: {
  imports = [
    ./hardware-configuration.nix
    ../common.nix
    ../../modules/system/hardware/firmware/vbt.nix
    ../../modules/system/hardware/ipu6-camera.nix
    ../../modules/system/scx-schedulers.nix
    ../../modules/profiles/vpn-workstation.nix
    ../../modules/system/hardware/droidcam.nix
  ];

  programs.steam = {
    enable = true;
    gamescopeSession.enable = true;
    extraPackages = [pkgs.sdl3];
    package = pkgs.steam.override {
      extraArgs = "-system-composer";
    };
  };

  services = {
    printing = {
      enable = true;
      drivers = [pkgs.gutenprint];
    };

    # Spectre uses smaller journal limit than the common 1G default
    journald.extraConfig = lib.mkForce ''
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

      # Prevent Realtek SD card reader from runtime suspending
      ACTION=="add", SUBSYSTEM=="pci", ATTR{vendor}=="0x10ec", ATTR{device}=="0x525a", ATTR{power/control}="on"
    '';
  };

  hardware = {
    enableRedistributableFirmware = true;
    keyboard.qmk.enable = true;
    graphics.extraPackages = [pkgs.intel-media-driver];
  };

  boot = {
    binfmt.emulatedSystems = ["aarch64-linux"];
    systemd-boot-defaults.enable = true;
    loader.efi.canTouchEfiVariables = false;
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
    kernelModules = [
      "hp_wmi"
    ];
    blacklistedKernelModules = [
      "iTCO_wdt"
      "watchdog"
    ];
    crashDump.enable = true;
  };

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

  # Limit build parallelism to keep the system responsive
  nix.settings = {
    cores = 8; # Leave 4 threads free for desktop responsiveness
    max-jobs = 2; # Max parallel derivation builds
  };

  users.users.kronberger.extraGroups = ["docker"];

  environment.systemPackages = with pkgs; [
    brightnessctl
    dmidecode
    docker-compose
  ];

  system.stateVersion = "24.11";
}
