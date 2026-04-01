{pkgs, host, ...}: {
  # Disable libcamera SPA plugin on hosts without IPU6 camera hardware.
  # On spectre, libcamera is needed for the built-in Intel IPU6 camera.
  services.pipewire.wireplumber.configPackages =
    if host != "spectre"
    then [
      (pkgs.writeTextDir "share/wireplumber/wireplumber.conf.d/99-disable-libcamera.conf" ''
        context.spa-libs = {
          api.libcamera.* = null
        }
      '')
    ]
    else [];
}
