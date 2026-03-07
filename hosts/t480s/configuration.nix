{pkgs, ...}: {
  imports = [
    ./hardware-configuration.nix
    ../common.nix
  ];

  boot = {
    systemd-boot-defaults.enable = true;
    loader.efi.canTouchEfiVariables = true;
    kernelParams = ["console=tty1"];
  };

  services = {
    printing = {
      enable = true;
      drivers = [pkgs.gutenprint];
    };
  };

  system.stateVersion = "24.11";
}
