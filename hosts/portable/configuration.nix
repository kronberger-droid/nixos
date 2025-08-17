# Edit this configuration file to define what should be installed on
# your system. Help is available in the configuration.nix(5) man page, on
# https://search.nixos.org/options and in the NixOS manual (`nixos-help`).

{ config, lib, pkgs, ... }:

{
  imports =
    [ # Include the results of the hardware scan.
      ./hardware-configuration.nix
      ../common.nix
    ];
  nix.settings.experimental-features = [ "nix-command" "flakes" ];

  boot.loader = {
    grub = {
      enable = true;
      efiSupport = true;
      efiInstallAsRemovable = true;
      device = "nodev";
    };
    efi.canTouchEfiVariables = false;
  };

  fileSystems."/" = lib.mkForce {
    device = "/dev/disk/by-label/NIXROOT_EXT";
    fsType = "ext4";
  };

  fileSystems."/boot" = lib.mkForce {
    device = "/dev/disk/by-label/NIXBOOT_EXT";
    fsType = "vfat";  
  };

  networking.hostName = "portable"; # Define your hostname.

  # Configure network connections interactively with nmcli or nmtui.
  networking.networkmanager.enable = true;

  # You can use https://search.nixos.org/ to find more packages (and options).
  environment.systemPackages = with pkgs; [
    helix
    git
  ];

  system.stateVersion = "25.11"; # Did you read the comment?

}

