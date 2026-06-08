{pkgs, ...}: {
  nix.settings.experimental-features = ["nix-command" "flakes"];

  imports = [
    ./hardware-configuration.nix
    ../../modules/system/core/helium.nix
    ../../modules/profiles/media-kiosk.nix
  ];

  # Shared browser-kiosk appliance, x86 flavour: Helium instead of Chromium.
  # AppImage Chromium forks default to X11/XWayland, so pass the Ozone/Wayland
  # flags explicitly (matches the Exec line baked into helium.desktop).
  mediaKiosk = {
    enable = true;
    user = "media";
    hostName = "mediaBox";
    browserPackage = pkgs.helium;
    browserCommand = "${pkgs.helium}/bin/helium --enable-features=UseOzonePlatform --ozone-platform=wayland";
  };

  # ── x86 boot / hardware ───────────────────────────────
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  hardware.graphics.enable = true;

  # It's a media appliance living on a shelf — don't suspend when the lid is
  # shut mid-stream, on battery or AC.
  services.logind = {
    lidSwitch = "ignore";
    lidSwitchExternalPower = "ignore";
  };

  system.stateVersion = "25.05";
}
