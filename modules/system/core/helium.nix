{...}: {
  # Helium — privacy-focused Chromium fork from imputnet, shipped only as an
  # x86_64 AppImage. Factored into its own overlay module so non-core hosts
  # (e.g. the x86 media kiosk) can get `pkgs.helium` without importing all of
  # modules/system/core/packages.nix.
  #
  # ARM note: there is no aarch64 AppImage upstream, so this overlay is a no-op
  # for usefulness on aarch64 — the mediaPi (Raspberry Pi) host stays on
  # Chromium. Only import + reference this on x86_64-linux hosts.
  nixpkgs.overlays = [
    (_: prev: {
      helium = let
        pname = "helium";
        version = "0.12.3.1";
        src = prev.fetchurl {
          url = "https://github.com/imputnet/helium-linux/releases/download/${version}/helium-${version}-x86_64.AppImage";
          hash = "sha256-VnOhzhAulvFNBB/0AD1d+K/TzfFL9Zwtk/vcm5vWl+I=";
        };
        appimageContents = prev.appimageTools.extractType2 {inherit pname version src;};
      in
        prev.appimageTools.wrapType2 {
          inherit pname version src;

          extraInstallCommands = ''
            install -m 444 -D ${appimageContents}/helium.desktop \
              $out/share/applications/helium.desktop
            install -m 444 -D ${appimageContents}/helium.png \
              $out/share/icons/hicolor/512x512/apps/helium.png
            substituteInPlace $out/share/applications/helium.desktop \
              --replace 'Exec=helium' 'Exec=helium --enable-features=UseOzonePlatform --ozone-platform=wayland'
          '';

          meta = {
            description = "Privacy-focused Chromium fork from imputnet";
            homepage = "https://helium.computer";
            platforms = ["x86_64-linux"];
          };
        };
    })
  ];
}
