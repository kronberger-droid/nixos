{
  pkgs,
  lib,
  ...
}: {
  # Intel IPU6 camera support (HI556 + OV2740 sensors)
  # Requires kernel 6.10+ for in-tree IPU6 drivers

  boot.kernelModules = [
    "intel_ipu6"
    "intel_ipu6_isys"
    "ipu_bridge"
    "ivsc_ace"
    "ivsc_csi"
    "mei_vsc"
    "mei_vsc_hw"
    "hi556"
    "ov2740"
  ];

  environment.systemPackages = with pkgs; [
    libcamera
    v4l-utils
  ];

  # Tuning files for libcamera's simple pipeline ISP
  environment.etc."libcamera/ipa/simple/hi556.yaml".text = ''
    %YAML 1.1
    ---
    version: 1
    algorithms:
      - BlackLevel:
          # HI556 is a 10-bit sensor; 64 at 10-bit = 4096 in 16-bit space
          blackLevel: 4096
      - Awb:
      - Adjust:
      - Agc:
  '';

  environment.etc."libcamera/ipa/simple/ov2740.yaml".text = ''
    %YAML 1.1
    ---
    version: 1
    algorithms:
      - BlackLevel:
      - Awb:
      - Adjust:
      - Agc:
  '';

  environment.variables.LIBCAMERA_IPA_CONFIG_PATH =
    "/etc/libcamera/ipa:${pkgs.libcamera}/share/libcamera/ipa";

  # Set digital gain on sensor probe (2x boost)
  services.udev.extraRules = ''
    SUBSYSTEM=="video4linux", KERNEL=="v4l-subdev*", ATTR{name}=="hi556*", ACTION=="add", RUN+="${pkgs.v4l-utils}/bin/v4l2-ctl -d /dev/$kernel --set-ctrl=digital_gain=2048"
    SUBSYSTEM=="video4linux", KERNEL=="v4l-subdev*", ATTR{name}=="ov2740*", ACTION=="add", RUN+="${pkgs.v4l-utils}/bin/v4l2-ctl -d /dev/$kernel --set-ctrl=digital_gain=2048"
  '';

  # Suspend/resume workaround: IPU6 firmware re-authentication fails after
  # S3 resume on kernel 6.16+, so unload modules before sleep and reload after
  powerManagement = {
    powerDownCommands = lib.mkAfter ''
      modprobe -r hi556 ov2740 intel_ipu6_isys intel_ipu6 || true
    '';
    resumeCommands = lib.mkAfter ''
      modprobe intel_ipu6
      modprobe intel_ipu6_isys
    '';
  };
}
