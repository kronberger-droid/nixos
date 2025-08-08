{ pkgs, ... }:

{
  imports = [
    ./hardware-configuration.nix
    ../common.nix
  ];

  programs.steam = {
    enable = true;
  };

  boot = {
    kernelParams = [
      "mem_sleep_default=s2idle"
    ];
  };

  system.stateVersion = "24.11";
}
