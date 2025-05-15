{ config, pkgs, ... }:

{
  imports =
    [ # Include the results of the hardware scan.
      ./hardware-configuration.nix
      ../common.nix
    ];

  services = {
    printing = {
      enable = true;
      drivers = [ pkgs.gutenprint ];
    };
  };  

  boot.kernelModules = [ "hp_wmi" ];

  system.stateVersion = "24.11"; # Did you read the comment?

}
