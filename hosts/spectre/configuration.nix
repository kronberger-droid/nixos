{ pkgs, ... }:
{
  imports =
    [
      ./hardware-configuration.nix
      ../common.nix
    ];

  services = {
    v4l2-relayd = {
      instances.ipu6 = {
        enable    = true;
        cardLabel = "Intel IPU6 MIPI Camera";
        input =
        {
          format    = "YUYV";
          width     = 1280;
          height    = 720;
          framerate = 30;
        };
        input.pipeline = ''
          v4l2src device=/dev/video33 \
            ! video/x-raw,format=YUYV,width=1280,height=720,framerate=30/1 \
            ! videoconvert
        '';
      };
    };
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
    enableRedistributableFirmware = true;
  };

  boot = {
    extraModulePackages = [
      pkgs.linuxKernel.packages.linux_6_12.ipu6-drivers
      pkgs.linuxKernel.packages.linux_6_12.v4l2loopback
    ];
    kernelModules = [
      "v4l2loopback"
      "hp_wmi"
    ];
    kernelParams = [
      # "i915.enable_psr=0"      # disable Panel Self Refresh
      # # add these:
      # "i915.enable_rc6=1"      # disable RC6 power‐saving states
      # "intel_idle.max_cstate=1" # prevent the CPU from entering deep C-states
      # "i915.enable_guc=0"      # disable GuC firmware loading
      # "i915.enable_fbc=1"      # disable Frame Buffer Compres
      # "mem_sleep_default=s2idle"
    ];
    blacklistedKernelModules = [
      "iTCO_wdt"
      "watchdog"
      "igen6_edac"
    ];
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
