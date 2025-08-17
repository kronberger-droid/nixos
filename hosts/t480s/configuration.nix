{ pkgs, ... }:
{
  imports = [
    ./hardware-configuration.nix
    ../common.nix
  ];

  boot = {
    loader = {
      systemd-boot.enable = true;
      efi.canTouchEfiVariables = true;
    };
    kernel.sysctl = {
      "vm.swappiness" = 10;
    };
    kernelParams = [
      "nowatchdog"
      "nmi_watchdog=0"
    ];
    blacklistedKernelModules = [
      "wdat_wdt"
    ];
  };

  services = {
    printing = {
      enable = true;
      drivers = [ pkgs.gutenprint ];
    };

    /*
    "06cb-009a-fingerprint-sensor" = {                                 
      enable = true;                                                            
      backend = "libfprint-tod";                                              
      # backend = "python-validity";
      calib-data-file = ./calib-data.bin;
    };
    */    
  };

  system.stateVersion = "24.11";
}
