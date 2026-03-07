{pkgs, ...}: {
  services.pipewire.wireplumber.configPackages = [
    (pkgs.writeTextDir "share/wireplumber/wireplumber.conf.d/99-disable-libcamera.conf" ''
      # Disable libcamera SPA plugin to prevent segfaults
      context.spa-libs = {
        api.libcamera.* = null
      }
    '')
  ];
}
