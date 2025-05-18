{ pkgs, ... }:

{
  imports = [
    ./hardware-configuration.nix
    ../common.nix
  ];

  programs.steam = {
    enable = true;
    pulseAudio.enable = true;
  };

  system.stateVersion = "24.11";
}
