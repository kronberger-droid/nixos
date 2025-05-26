{ pkgs, ... }:

{
  imports =
    [ # Include the results of the hardware scan.
      ./hardware-configuration.nix
      ../common.nix
    ];

  services = {
    printing = {
      enable = true;
      drivers = [ pkgs.gutenprint ];
    };
  };  

  hardware = {
    ipu6 = {
      enable = true;
      platform = "ipu6ep";
    };
    enableRedistributableFirmware = true;
  };

  boot = {
    kernelModules = [ "hp_wmi" ];
    kernelParams = [ "i915.enable_psr=0" "mem_sleep_default=deep" ];
    blacklistedKernelModules = [ "iTCO_wdt" "watchdog" ];
  };

  systemd.sleep.extraConfig = ''
    SuspendState=mem
  '';

  environment.systemPackages = with pkgs; [
    libcamera
    v4l-utils
    ipu6-camera-bins
  ];

  system.stateVersion = "24.11"; # Did you read the comment?

}
