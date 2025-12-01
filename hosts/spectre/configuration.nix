{
  pkgs,
  config,
  ...
}: {
  imports = [
    ./hardware-configuration.nix
    ../common.nix
    ../../modules/system/firmware/vbt.nix
    ../../modules/system/scx-schedulers.nix
  ];

  services = {
    printing = {
      enable = true;
      drivers = [pkgs.gutenprint];
    };

    pia = {
      enable = true;
      authUserPassFile = config.age.secrets.pia-credentials.path;
    };

    tuwien-vpn = {
      enable = true;
      passwordFile = config.age.secrets.tuwien-vpn-password.path;
    };

    logind.settings.Login = {
      HandleLidSwitch = "suspend-then-hibernate";
      HandleLidSwitchDocked = "ignore";
      HandleLidSwitchExternalPower = "suspend";
    };

    journald = {
      storage = "persistent";
      forwardToSyslog = true;
      extraConfig = ''
        Compress=yes
        SystemMaxUse=500M
        RuntimeMaxUse=100M
      '';
    };

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
    kernelPackages = pkgs.linuxPackages_latest;
    initrd.systemd.enable = true;
    loader = {
      systemd-boot = {
        enable = true;
        editor = false;
        configurationLimit = 20;
      };
      timeout = 1;
      efi.canTouchEfiVariables = false;
    };
    kernel.sysctl = {
      "kernel.sysrq" = 1;
    };
    kernelParams = [
      "nvme_core.default_ps_max_latency_us=0"
      "pcie_aspm=off"
      "snd_intel_dspcfg.dsp_driver=1"
      "intel_iommu=off"
    ];
    kernelModules = [
      "hp_wmi"
      "v4l2loopback"
      "ip_tables"
      "iptable_filter"
      "iptable_nat"
      "iptable_mangle"
    ];
    extraModulePackages = [
      config.boot.kernelPackages.v4l2loopback
    ];
    blacklistedKernelModules = [
      "iTCO_wdt"
      "watchdog"
    ];
    crashDump.enable = true;
  };

  systemd.sleep.extraConfig = ''
    SuspendState=mem
    HibernateDelaySec=90m
  '';

  environment.systemPackages = with pkgs; [
    brightnessctl
    light
    dmidecode
  ];

  system.stateVersion = "24.11"; # Did you read the comment?
}
