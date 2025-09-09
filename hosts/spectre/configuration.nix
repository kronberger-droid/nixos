{ pkgs, ... }:
{
  imports =
    [
      ./hardware-configuration.nix
      ../common.nix
      ../../modules/system/firmware/vbt.nix
    ];

  services = {
    printing = {
      enable = true;
      drivers = [ pkgs.gutenprint ];
    };

    logind.settings.Login = {
      lidSwitch = "suspend-then-hibernate";
      lidSwitchDocked = "ignore";
      lidSwitchExternalPower = "suspend";
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
  };  

  hardware = {
    enableRedistributableFirmware = true;
    ipu6 = {
      enable = true;
      platform = "ipu6ep";
    };
  };

  boot = {
    loader = {
      systemd-boot.enable = true;
      efi.canTouchEfiVariables = true;
    };
    kernel.sysctl = {
      "vm.swappiness" = 10;
      "kernel.sysrq" = 1;
    };
    kernelParams = [
      "nowatchdog"
      "nmi_watchdog=0"
    ];
    kernelModules = [
      "hp_wmi"
      "nvme_core.default_ps_max_latency_us=0"
      "pcie_aspm=off"
      "v4l2loopback"
    ];
    extraModulePackages = [ pkgs.linuxPackages.v4l2loopback ];
    blacklistedKernelModules = [
      "wdat_wdt"
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
    v4l-utils
    cheese
    libcamera
    gst_all_1.gstreamer
    gst_all_1.gst-plugins-base
    gst_all_1.gst-plugins-good
    gst_all_1.gst-plugins-bad
    gst_all_1.gst-plugins-ugly
  ];

  system.stateVersion = "24.11"; # Did you read the comment?

}
