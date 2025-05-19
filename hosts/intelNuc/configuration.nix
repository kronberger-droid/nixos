{ pkgs, ... }:

{
  imports = [
    ./hardware-configuration.nix
    ../common.nix
  ];

  programs.steam = {
    enable = true;
  };

  system.stateVersion = "24.11";
}
