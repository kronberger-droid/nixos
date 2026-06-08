{
  pkgs,
  modulesPath,
  ...
}: {
  nix.settings.experimental-features = ["nix-command" "flakes"];

  imports = [
    (modulesPath + "/installer/sd-card/sd-image-aarch64.nix")
    ../../modules/system/desktop/keyd.nix
    ../../modules/profiles/media-kiosk.nix
  ];

  # Shared browser-kiosk appliance. ARM, so it stays on Chromium (Helium is
  # x86_64-only). browserCommand defaults to ${pkgs.chromium}/bin/chromium.
  mediaKiosk = {
    enable = true;
    user = "mediaPi";
    hostName = "mediaPi";
    browserPackage = pkgs.chromium;
  };

  # Chromium policy — set itself as default browser handler. Browser-specific,
  # so it lives here rather than in the (browser-agnostic) kiosk profile.
  programs.chromium = {
    enable = true;
    extraOpts = {
      "DefaultBrowserSettingEnabled" = true;
    };
  };

  # ── Raspberry Pi 4 hardware / boot ────────────────────
  # Compressed SD image to save disk
  sdImage.compressImage = true;

  # Pi 4 — mainline kernel (cached on cache.nixos.org, unlike linux-rpi)
  boot.kernelPackages = pkgs.linuxPackages_latest;
  hardware.graphics.enable = true;

  # GPIO 3 (pin 5) power button — press to shutdown, press again to wake
  hardware.deviceTree.overlays = [
    {
      name = "gpio-shutdown";
      dtsText = ''
        /dts-v1/;
        /plugin/;
        / {
          compatible = "brcm,bcm2711";
          fragment@0 {
            target-path = "/soc/gpio";
            __overlay__ {
              shutdown_button: shutdown_button {
                compatible = "gpio-keys";
                #address-cells = <1>;
                #size-cells = <0>;
                button: button@0 {
                  label = "shutdown";
                  linux,code = <116>; /* KEY_POWER */
                  gpios = <&gpio 3 1>; /* GPIO 3, active low */
                  debounce-interval = <50>;
                };
              };
            };
          };
        };
      '';
    }
  ];

  system.stateVersion = "25.05";
}
