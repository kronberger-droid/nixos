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
  };

  system.stateVersion = "24.05";
}
