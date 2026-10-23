{
  lib,
  pkgs,
  inputs,
  ...
}: let
  mkNixPak = inputs.nixpak.lib.nixpak {inherit lib pkgs;};

  # ZapZap (WhatsApp Web in QtWebEngine) in a bubblewrap sandbox, on the
  # pattern of signal.nix. It keeps its session in ~/.local/share/ZapZap and
  # needs no Secret Service.
  zapzap = mkNixPak {
    config = {sloth, ...}: {
      imports = with inputs.nixpak.nixpakModules; [gui-base network];

      app.package = pkgs.zapzap;
      flatpak.appId = "com.rtosta.zapzap";

      # gui-base bundles its own mesa; the host's driver matches the kernel
      # and is already in the store.
      gpu.provider = lib.mkForce "nixos";

      dbus.policies = {
        # It notifies over both this and the portal, depending on settings.
        "org.freedesktop.Notifications" = "talk";
        "org.kde.StatusNotifierWatcher" = "talk";
      };

      bubblewrap = {
        bind.rw = [
          # The linked session lives here, so a fresh dir would mean scanning
          # the QR code again.
          (sloth.mkdir (sloth.concat' sloth.xdgDataHome "/ZapZap"))
          (sloth.mkdir (sloth.concat' sloth.xdgConfigHome "/ZapZap"))
          (sloth.concat' sloth.homeDir "/Downloads")
          # A private /tmp, see signal.nix.
          [(sloth.mkdir (sloth.concat' sloth.appCacheDir "/tmp")) "/tmp"]
        ];
      };
    };
  };
in {
  home.packages = [zapzap.config.env];
}
