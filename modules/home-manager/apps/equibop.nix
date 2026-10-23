{
  lib,
  pkgs,
  inputs,
  ...
}: let
  mkNixPak = inputs.nixpak.lib.nixpak {inherit lib pkgs;};

  # Equibop in a bubblewrap sandbox, on the same pattern as signal.nix: its
  # own profile, Downloads, the cameras and the session services a voice
  # client needs. Unlike Signal it gets no Secret Service: nothing in its
  # profile is pinned to libsecret, and `talk` there is the whole keyring.
  equibop = mkNixPak {
    config = {sloth, ...}: {
      imports = with inputs.nixpak.nixpakModules; [gui-base network];

      app.package = pkgs.equibop;
      flatpak.appId = "io.github.equicord.equibop";

      # gui-base bundles its own mesa; the host's driver matches the kernel
      # and is already in the store.
      gpu.provider = lib.mkForce "nixos";

      dbus.policies = {
        # Electron notifies through libnotify, not the portal.
        "org.freedesktop.Notifications" = "talk";
        "org.kde.StatusNotifierWatcher" = "talk";
      };

      bubblewrap = {
        bind.rw = [
          # The real profile: it holds the login and the Equicord settings.
          (sloth.mkdir (sloth.concat' sloth.xdgConfigHome "/equibop"))
          (sloth.concat' sloth.homeDir "/Downloads")
          # A private /tmp. The mkdir also creates the app cache dir that
          # gui-base maps onto ~/.cache, see signal.nix.
          [(sloth.mkdir (sloth.concat' sloth.appCacheDir "/tmp")) "/tmp"]
        ];
        # Cameras for video calls. P14E's UVC module enumerates low, intelNuc
        # only has the DroidCam loopback (video_nr=42, droidcam.nix). Bound
        # with --dev-bind-try, so absent nodes are skipped.
        bind.dev = map (n: "/dev/video${toString n}") [0 1 2 3 42];
        # Calls, and venmic's screenshare audio, which talks to PipeWire
        # directly. Screenshare video goes through the ScreenCast portal.
        sockets.pipewire = true;
      };
    };
  };
in {
  home.packages = [equibop.config.env];
}
