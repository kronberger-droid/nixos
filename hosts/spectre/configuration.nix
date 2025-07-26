{ pkgs, ... }:
{
  imports =
    [
      ./hardware-configuration.nix
      ../common.nix
    ];

  services = {
    printing = {
      enable = true;
      drivers = [ pkgs.gutenprint ];
    };
    logind = {
      lidSwitch = "suspend-then-hibernate";
      lidSwitchDocked = "ignore";
      lidSwitchExternalPower = "suspend";
    };
    # Better logging for crash analysis
    journald = {
      storage = "persistent";
      forwardToSyslog = true;
      extraConfig = ''
        Compress=yes
        SystemMaxUse=500M
        RuntimeMaxUse=100M
      '';
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
      "i915.enable_fbc=0"        # disable Frame Buffer Compression
    ];
    kernelPatches = [
      {
        name = "Fix freeze after sleep";
        patch = ../../patches/sleep.patch;
      }
    ];
    blacklistedKernelModules = [
      "iTCO_wdt"
      "watchdog"
      "igen6_edac"
    ];
    # Enable crash dumps and better debugging
    crashDump.enable = true;
    kernel.sysctl."kernel.sysrq" = 1;
  };

  systemd.sleep.extraConfig = ''
    SuspendState=mem
    HibernateDelaySec=90m
  '';

  powerManagement.enable = true;


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
