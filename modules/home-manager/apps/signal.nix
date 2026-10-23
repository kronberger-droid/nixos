{
  lib,
  pkgs,
  inputs,
  ...
}: let
  mkNixPak = inputs.nixpak.lib.nixpak {inherit lib pkgs;};

  # Signal in a bubblewrap sandbox. It sees its own data, Downloads and the
  # session services it needs, and nothing else of the home directory: no
  # ~/.ssh, and no oo7 SSH agent socket, since only the listed parts of
  # $XDG_RUNTIME_DIR are mounted. SSH_AUTH_SOCK is still inherited, but it
  # points at a path that is not there.
  signal = mkNixPak {
    config = {sloth, ...}: {
      imports = with inputs.nixpak.nixpakModules; [gui-base network];

      app.package = pkgs.signal-desktop;
      flatpak.appId = "org.signal.Signal";

      # gui-base bundles its own mesa; the host's driver matches the kernel
      # and is already in the store.
      gpu.provider = lib.mkForce "nixos";

      dbus.policies = {
        # Signal encrypts its database key with safeStorage, pinned to
        # gnome_libsecret in config.json. That talks to the Secret Service
        # directly, not through the portal, so without this the existing
        # database cannot be opened. It is the same access Signal had
        # unsandboxed: the Secret Service has no per-app isolation.
        "org.freedesktop.secrets" = "talk";
        # Electron notifies through libnotify, not the portal.
        "org.freedesktop.Notifications" = "talk";
        "org.kde.StatusNotifierWatcher" = "talk";
      };

      bubblewrap = {
        bind.rw = [
          # The real profile, not ~/.var/app/org.signal.Signal: it holds the
          # linked account, so a fresh dir would mean relinking the device.
          (sloth.mkdir (sloth.concat' sloth.xdgConfigHome "/Signal"))
          (sloth.concat' sloth.homeDir "/Downloads")
          # A private /tmp. The mkdir also creates the app cache dir that
          # gui-base maps onto ~/.cache: it binds with --bind-try, which
          # silently skips a missing source.
          [(sloth.mkdir (sloth.concat' sloth.appCacheDir "/tmp")) "/tmp"]
        ];
        sockets.pipewire = true;
        # Chromium only tries libsecret when this names GNOME, and falls
        # back to basic_text otherwise, which cannot open the database
        # (safeStorageBackend is pinned to gnome_libsecret). niri hands its
        # children "niri:GNOME" (desktop/niri.nix), but a shell can carry
        # the plain "niri" from home.sessionVariables, so pin it here.
        env.XDG_CURRENT_DESKTOP = "niri:GNOME";
      };
    };
  };
in {
  home.packages = [signal.config.env];
}
