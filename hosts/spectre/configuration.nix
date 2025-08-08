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
    kernelModules = [
      "hp_wmi"
    ];
    # kernelPatches = [
    #   {
    #     name = "Fix freeze after sleep";
    #     patch = ../../patches/sleep.patch;
    #   }
    # ];
    blacklistedKernelModules = [
      "iTCO_wdt"
      "watchdog"
    ];
    # Enable crash dumps and better debugging
    crashDump.enable = true;
    kernel.sysctl."kernel.sysrq" = 1;
  };

  systemd.sleep.extraConfig = ''
    SuspendState=mem
    HibernateDelaySec=90m
  '';

  system.stateVersion = "24.11"; # Did you read the comment?

}
