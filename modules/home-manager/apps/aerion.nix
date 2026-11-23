{
  lib,
  pkgs,
  inputs,
  ...
}: let
  mkNixPak = inputs.nixpak.lib.nixpak {inherit lib pkgs;};

  # Aerion (mail, Wails on WebKitGTK) in a bubblewrap sandbox, on the
  # pattern of signal.nix. Attachments come in through the FileChooser
  # portal, which Aerion calls directly, so no document folders are bound.
  aerion = mkNixPak {
    config = {sloth, ...}: {
      imports = (with inputs.nixpak.nixpakModules; [gui-base network]) ++ [./nixpak-common.nix];

      app.package = pkgs.aerion;
      flatpak.appId = "io.github.hkdb.Aerion";

      dbus.policies = {
        # Account passwords and OAuth tokens go through go-keyring, which
        # talks to the Secret Service directly. Same trade-off as Signal:
        # the Secret Service has no per-app isolation.
        "org.freedesktop.secrets" = "talk";
        "org.freedesktop.Notifications" = "talk";
        "org.kde.StatusNotifierWatcher" = "talk";
      };

      bubblewrap = {
        # gui-base's default. This app plays and records nothing.
        sockets.pulse = lib.mkForce false;
        bind.rw = [
          # accounts/ here, the mail database and keys in the data dir.
          (sloth.mkdir (sloth.concat' sloth.xdgConfigHome "/aerion"))
          (sloth.mkdir (sloth.concat' sloth.xdgDataHome "/aerion"))
        ];
      };
    };
  };
in {
  home.packages = [aerion.config.env];
}
