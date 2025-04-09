{ pkgs, ... }:
{
  imports = [
    ./hardware-configuration.nix
    ../common.nix
  ];

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
