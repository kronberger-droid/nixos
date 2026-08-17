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
