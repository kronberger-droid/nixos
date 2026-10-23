{
  lib,
  pkgs,
  inputs,
  ...
}: let
  mkNixPak = inputs.nixpak.lib.nixpak {inherit lib pkgs;};

  # LocalSend in a bubblewrap sandbox, on the pattern of signal.nix. It
  # receives into ~/Downloads and sends what the FileChooser portal hands
  # it. The network preset shares the host's network namespace, so the
  # multicast discovery on 53317 (security.nix opens it) still reaches the
  # LAN.
  localsend = mkNixPak {
    config = {sloth, ...}: {
      imports = with inputs.nixpak.nixpakModules; [gui-base network];

      app.package = pkgs.localsend;
      flatpak.appId = "org.localsend.localsend_app";

      # gui-base bundles its own mesa; the host's driver matches the kernel
      # and is already in the store.
      gpu.provider = lib.mkForce "nixos";

      dbus.policies = {
        "org.freedesktop.Notifications" = "talk";
        "org.kde.StatusNotifierWatcher" = "talk";
      };

      bubblewrap = {
        bind.rw = [
          # Settings and the device alias (shared_preferences.json).
          (sloth.mkdir (sloth.concat' sloth.xdgDataHome "/org.localsend.localsend_app"))
          (sloth.concat' sloth.homeDir "/Downloads")
          # A private /tmp, see signal.nix.
          [(sloth.mkdir (sloth.concat' sloth.appCacheDir "/tmp")) "/tmp"]
        ];
      };
    };
  };
in {
  home.packages = [localsend.config.env];
}
