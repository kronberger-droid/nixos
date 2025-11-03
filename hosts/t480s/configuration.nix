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
  };

  services = {
    printing = {
      enable = true;
      drivers = [ pkgs.gutenprint ];
    };
  };

  system.stateVersion = "24.11";
}
