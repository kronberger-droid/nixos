{ pkgs, ... }:
{
  imports = [
    ./hardware-configuration.nix
    ../common.nix
  ];

  boot = {
    initrd.systemd.enable = true; # Faster boot with systemd in initrd
    loader = {
      systemd-boot = {
        enable = true;
        editor = false; # Disable boot menu editor for security
        configurationLimit = 20; # Limit number of stored generations
      };
      timeout = 1; # Fast boot menu timeout
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
