{
  lib,
  pkgs,
  inputs,
  ...
}: let
  mkNixPak = inputs.nixpak.lib.nixpak {inherit lib pkgs;};
  hs = import ../../shared/homeserver.nix;

  # Links go to Electron's shell.openExternal, which runs `xdg-open`; the
  # sandbox has none on its PATH. Same portal shim as equibop.nix, which
  # explains why the nixpkgs one does not take the portal route under nixpak.
  xdgOpen = pkgs.writeShellScriptBin "xdg-open" ''
    exec ${pkgs.glib.bin}/bin/gdbus call --session \
      --dest org.freedesktop.portal.Desktop \
      --object-path /org/freedesktop/portal/desktop \
      --method org.freedesktop.portal.OpenURI.OpenURI \
      --timeout 5 "" "$1" {}
  '';

  # Element in a bubblewrap sandbox, on the pattern of signal.nix: its own
  # profile, Downloads, and the session services a chat and call client
  # needs.
  element = mkNixPak {
    config = {sloth, ...}: {
      imports = with inputs.nixpak.nixpakModules; [gui-base network];

      app.package = pkgs.element-desktop;
      flatpak.appId = "im.riot.Riot";

      # gui-base bundles its own mesa; the host's driver matches the kernel
      # and is already in the store.
      gpu.provider = lib.mkForce "nixos";

      # Binds the host's /etc/localtime. Without it there is none in the
      # sandbox and every timestamp shows in UTC.
      timeZone.enable = true;

      dbus.policies = {
        # Element keeps its store key in Electron safeStorage, which needs a
        # real keyring (newer Element refuses the plaintext "basic" store,
        # see desktop/niri.nix). Under nixpak libsecret takes the Secret
        # portal route, which needs oo7-portal 0.7.1 (backports-overlay.nix).
        # Same trade-off as Signal: the Secret Service has no per-app
        # isolation.
        "org.freedesktop.secrets" = "talk";
        # Electron notifies through libnotify, not the portal.
        "org.freedesktop.Notifications" = "talk";
        "org.kde.StatusNotifierWatcher" = "talk";
      };

      bubblewrap = {
        bind.rw = [
          # The real profile: session, crypto store and config.json.
          (sloth.mkdir (sloth.concat' sloth.xdgConfigHome "/Element"))
          (sloth.concat' sloth.homeDir "/Downloads")
          # A private /tmp. The mkdir also creates the app cache dir that
          # gui-base maps onto ~/.cache, see signal.nix.
          [(sloth.mkdir (sloth.concat' sloth.appCacheDir "/tmp")) "/tmp"]
        ];
        # Voice and video calls.
        sockets.pipewire = true;
        # Chromium only tries libsecret when this names GNOME, see signal.nix.
        env.XDG_CURRENT_DESKTOP = "niri:GNOME";
        env.PATH = lib.makeBinPath [xdgOpen pkgs.coreutils];
      };
    };
  };
in {
  programs.element-desktop = {
    enable = true;
    # The sandboxed build goes in below; the module only writes config.json.
    package = null;
    settings = {
      default_server_config."m.homeserver" = {
        base_url = hs.matrixUrl;
        server_name = hs.matrixServerName;
      };
      # Registration is closed on our server, so no guest prompts.
      disable_guests = true;
      show_labs_settings = true;
    };
  };

  home.packages = [element.config.env];
}
