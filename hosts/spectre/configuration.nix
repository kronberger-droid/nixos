{ pkgs, ... }:

{
  imports =
    [ # Include the results of the hardware scan.
      ./hardware-configuration.nix
      ../common.nix
    ];

  services = {
    # v4l2-relayd.instances.ipu6 = {
    #   enable       = true;
    #   cardLabel    = "Intel IPU6 Camera";
    #   input.format   = "YUYV";   # index 21
    #   input.width    = 1920;     # your chosen resolution
    #   input.height   = 1080;
    #   input.framerate = 30;       # fps
    # };
    printing = {
      enable = true;
      drivers = [ pkgs.gutenprint ];
    };
    logind = {
      lidSwitch = "suspend-then-hibernate";
      lidSwitchDocked = "ignore";
      lidSwitchExternalPower = "suspend";
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
    kernelModules = [
      "v4l2loopback"
      "hp_wmi"
      "intel_ipu6"
      "intel_ipu6-drv"
      "intel_ipu6-ipu6"
    ];
    kernelParams = [ "i915.enable_psr=0" "mem_sleep_default=s2idle" ];
    blacklistedKernelModules = [ "iTCO_wdt" "watchdog" ];
  };

  systemd.sleep.extraConfig = ''
    SuspendState=mem
  '';

  environment.systemPackages = with pkgs; [
    libcamera
    v4l-utils
    ipu6-camera-bins
    gst_all_1.gstreamer
    gst_all_1.gst-plugins-base
    gst_all_1.gst-plugins-good
    gst_all_1.gst-plugins-bad
    gst_all_1.gst-libav
    gst_all_1.icamerasrc-ipu6ep
  ];

  system.stateVersion = "24.11"; # Did you read the comment?

}
