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

      # Allow access to IIO devices for screen rotation
      SUBSYSTEM=="iio", KERNEL=="iio:device*", MODE="0666"
    '';
  };

  hardware = {
    enableRedistributableFirmware = true;
    keyboard.qmk.enable = true;
  };

  boot = {
    systemd-boot-defaults.enable = true;
    loader.efi.canTouchEfiVariables = false;
    kernel.sysctl = {
      "kernel.sysrq" = 1;
    };
    kernelParams = [
      "nvme_core.default_ps_max_latency_us=0"
      "pcie_aspm=off"
      "snd_intel_dspcfg.dsp_driver=1"
      "intel_iommu=off"
      "console=tty1"
    ];
    kernelModules = [
      "hp_wmi"
      "v4l2loopback"
    ];
    extraModulePackages = [
      config.boot.kernelPackages.v4l2loopback
    ];
    extraModprobeConfig = ''
      options v4l2loopback devices=1 video_nr=42 card_label="DroidCam" exclusive_caps=1
    '';
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
  virtualisation.docker = {
    enable = true;
    autoPrune = {
      enable = true;
      dates = "weekly";
    };
  };

  users.users.kronberger.extraGroups = ["docker"];

  environment.systemPackages = with pkgs; [
    brightnessctl
    dmidecode
    droidcam
    android-tools
    docker-compose
  ];

  system.stateVersion = "24.11";
}
