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

    logind = {
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
    ];
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

  system.stateVersion = "24.11"; # Did you read the comment?

}
