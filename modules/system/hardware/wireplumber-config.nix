{pkgs, host, ...}: let
  ipu6Hosts = ["spectre" "P14E"];
in {
  # Disable libcamera SPA plugin on hosts without IPU6 camera hardware.
  # spectre and P14E both need libcamera for their built-in Intel IPU6 camera.
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
