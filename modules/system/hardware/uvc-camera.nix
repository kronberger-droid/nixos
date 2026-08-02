{pkgs, ...}: {
  # USB UVC webcam tuning (Foxlink 05c8:03e9 "HD Camera").
  #
  # The sensor tops out at 1280x720, and 720p is only offered in MJPG.
  # The uncompressed YUYV format caps at 640x480, so apps that negotiate
  # YUYV silently drop to 480p.

  environment.systemPackages = [pkgs.v4l-utils];

  # UVC controls persist on the device until it is re-enumerated, so
  # applying them once on probe is enough. Matched on vendor/product plus
  # the node name so the rule skips the IR sensor (used for face unlock,
  # not video) and the metadata node, and never touches DroidCam.
  services.udev.extraRules = ''
    SUBSYSTEM=="video4linux", KERNEL=="video*", ACTION=="add", ATTR{index}=="0", ATTR{name}=="HD Camera: HD Camera", ATTRS{idVendor}=="05c8", ATTRS{idProduct}=="03e9", RUN+="${pkgs.v4l-utils}/bin/v4l2-ctl -d /dev/%k --set-ctrl=power_line_frequency=1,sharpness=3,backlight_compensation=1"
  '';

  # power_line_frequency=1 (50 Hz) matches the European mains and stops
  #   banding under artificial light. The device default is 60 Hz.
  # sharpness=3 of 0..5. The device default is 0, i.e. sharpening fully
  #   off, which leaves this already-soft 720p sensor looking mushy.
  # backlight_compensation=1 raises exposure for a backlit subject, the
  #   usual laptop case of sitting with a window behind you. Drop it to 0
  #   if the image looks blown out in even lighting.

  # Both cameras on this module land in PipeWire with the same generated
  # node.description, "HD Camera (V4L2)", so no app's device picker can
  # tell them apart. Give them distinct names. The IR one is a 640x360
  # 8-bit greyscale sensor meant for face unlock, and picking it by
  # accident looks like a badly broken colour camera.
  services.pipewire.wireplumber.configPackages = [
    (pkgs.writeTextDir "share/wireplumber/wireplumber.conf.d/51-uvc-camera-names.conf" ''
      monitor.v4l2.rules = [
        {
          matches = [
            { api.v4l2.cap.card = "HD Camera: HD Camera" }
          ]
          actions = {
            update-props = {
              node.description = "HD Camera (colour)"
              node.nick = "HD Camera"
            }
          }
        }
        {
          matches = [
            { api.v4l2.cap.card = "HD Camera: IR Camera" }
          ]
          actions = {
            update-props = {
              node.description = "HD Camera (infrared, face unlock)"
              node.nick = "IR Camera"
            }
          }
        }
      ]
    '')
  ];
}
