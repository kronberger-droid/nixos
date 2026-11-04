{
  pkgs,
  host,
  ...
}: let
  ipu6Hosts = ["spectre"];
in {
  # Disable libcamera SPA plugin on hosts without IPU6 camera hardware.
  # Only spectre needs libcamera, for its built-in Intel IPU6 camera. On a
  # host whose webcam is plain USB UVC, leaving the plugin enabled makes
  # libcamera re-expose that same camera through its generic uvcvideo
  # pipeline handler, so PipeWire lists each camera twice and apps can
  # land on the duplicate, which has no IPA tuning behind it.
  # Keep Bluetooth headsets in A2DP. By default WirePlumber flips them to
  # HFP/HSP whenever an app opens a mic, and the WH-1000XM3 errors out on
  # that switch (input and output nodes fail together), which breaks Discord
  # audio. With this off, calls use the laptop mic and the headset stays stereo.
  services.pipewire.wireplumber.extraConfig."51-bluetooth-no-autoswitch" = {
    "wireplumber.settings" = {
      "bluetooth.autoswitch-to-headset-profile" = false;
    };
  };

  services.pipewire.wireplumber.configPackages =
    if !(builtins.elem host ipu6Hosts)
    then [
      (pkgs.writeTextDir "share/wireplumber/wireplumber.conf.d/99-disable-libcamera.conf" ''
        context.spa-libs = {
          api.libcamera.* = null
        }
      '')
    ]
    else [];
}
