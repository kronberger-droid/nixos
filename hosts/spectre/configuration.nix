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
    blacklistedKernelModules = [
      "iTCO_wdt"
      "watchdog"
      "igen6_edac"
    ];
  };

  systemd.sleep.extraConfig = ''
    SuspendState=mem
    HibernateDelaySec=90m
  '';

  powerManagement = {
    enable = true;
    resumeCommands = ''
      echo "System resumed from suspend"
      # Re-enable bluetooth if needed
      systemctl restart bluetooth.service || true
    '';
  };

  services.udev.extraRules = ''
    # Disable wakeup for problematic PCI devices
    ACTION=="add", SUBSYSTEM=="pci", DRIVER=="pcieport", ATTR{power/wakeup}="disabled"
    # Disable USB controller wakeup except for keyboard/mouse
    ACTION=="add", SUBSYSTEM=="pci", ATTRS{vendor}=="0x8086", ATTRS{device}=="0x7e7d", ATTR{power/wakeup}="disabled"
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
