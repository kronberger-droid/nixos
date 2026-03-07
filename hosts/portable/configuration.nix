{pkgs, ...}: {
  imports = [
    ./hardware-configuration.nix
    ../common.nix
  ];

  boot = {
    kernelParams = [
      "nowatchdog"
      "nmi_watchdog=0"
      "console=tty1"
    ];
    blacklistedKernelModules = [
      "wdat_wdt"
    ];
    loader = {
      timeout = 1;
      grub = {
        enable = true;
        efiSupport = true;
        efiInstallAsRemovable = true;
        device = "nodev";
        configurationLimit = 20;
      };
      efi.canTouchEfiVariables = false;
    };
  };

  fileSystems."/mnt/data" = {
    device = "/dev/disk/by-uuid/18d5e6e0-05b6-4496-b056-47a3fafd9acb";
    fsType = "ext4";
    options = ["defaults"];
  };

  systemd.tmpfiles.rules = [
    "d /mnt/data 0755 kronberger users - -"
  ];

  environment.systemPackages = with pkgs; [
    helix
    git
  ];

  system.stateVersion = "25.11";
}
