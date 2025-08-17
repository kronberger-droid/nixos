{ lib, pkgs, ... }:

{
  imports =
    [ # Include the results of the hardware scan.
      ./hardware-configuration.nix
      ../common.nix
    ];
  nix.settings.experimental-features = [ "nix-command" "flakes" ];

  boot = {
    kernelParams = [
      "nowatchdog"
      "nmi_watchdog=0"
    ];
    blacklistedKernelModules = [
      "wdat_wdt"
    ];
    loader = {
      grub = {
        enable = true;
        efiSupport = true;
        efiInstallAsRemovable = true;
        device = "nodev";
      };
      efi.canTouchEfiVariables = false;
    };
  };

  fileSystems."/mnt/data" = {
    device = "/dev/disk/by-uuid/bc997ac9-9068-4b5a-a89e-bf3d891d315f";
    fsType = "ext4";
    options = [ "defaults" ];
  };

  networking.hostName = "portable";

  networking.networkmanager.enable = true;

  environment.systemPackages = with pkgs; [
    helix
    git
  ];

  system.stateVersion = "25.11"; # Did you read the comment?
}

