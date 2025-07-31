{ pkgs, ... }:
{
  imports =
    [
      ./hardware-configuration.nix
      ../common.nix
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
    # Better logging for crash analysis
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
    kernelPatches = [
      {
        name = "Fix freeze after sleep";
        patch = ../../patches/sleep.patch;
      }
    ];
    blacklistedKernelModules = [
      "iTCO_wdt"
      "watchdog"
      "igen6_edac"
    ];
    # Enable crash dumps and better debugging
    crashDump.enable = true;
    kernel.sysctl."kernel.sysrq" = 1;
  };

  systemd.sleep.extraConfig = ''
    SuspendState=mem
    HibernateDelaySec=90m
  '';

  powerManagement.enable = true;


  # environment.systemPackages = with pkgs; [
  # ];

  system.stateVersion = "24.11"; # Did you read the comment?

}
