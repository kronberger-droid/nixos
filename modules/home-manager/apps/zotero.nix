{
  lib,
  pkgs,
  inputs,
  ...
}: let
  mkNixPak = inputs.nixpak.lib.nixpak {inherit lib pkgs;};

  # Zotero in a bubblewrap sandbox, on the pattern of signal.nix. It renders
  # web snapshots and PDFs from wherever papers come from, so its reach is
  # cut to the library, its profile and Downloads. Every attachment is a
  # stored file under ~/Zotero (no linked files), so nothing else is needed.
  #
  # The network is shared rather than cut: sync and metadata lookups need it,
  # and so does the local API on localhost:23119 that zotero-mcp
  # (claude-settings.nix) and the browser connector talk to.
  zotero = mkNixPak {
    config = {sloth, ...}: {
      imports = (with inputs.nixpak.nixpakModules; [gui-base network]) ++ [./nixpak-common.nix];

      app.package = pkgs.zotero;
      flatpak.appId = "org.zotero.Zotero";

      dbus.policies = {
        "org.freedesktop.Notifications" = "talk";
      };

      # A trial, on the app with the least to lose. The raw compositor
      # socket gives a sandboxed client what any Wayland client gets on
      # niri: the clipboard of every app, screen capture, synthetic input.
      # The proxy passes the core protocols only. If Zotero misbehaves
      # (scaling, clipboard, popups), remove this line; if it holds up, it
      # moves to nixpak-common.nix for all six. No title tag, which would
      # break window rules that match on titles.
      waylandProxy.enable = true;
      waylandProxy.tag = "";

      bubblewrap = {
        # gui-base's default. This app plays and records nothing.
        sockets.pulse = lib.mkForce false;
        bind.rw = [
          # The library and attachments (extensions.zotero.dataDir).
          (sloth.concat' sloth.homeDir "/Zotero")
          # The profile, which also holds the sync login.
          (sloth.mkdir (sloth.concat' sloth.homeDir "/.zotero"))
        ];
        # Its launcher (lib/zotero) is a shell script that calls dirname and
        # readlink by name. The inherited PATH points at host profiles that
        # are not mounted here, so without this it exits 127.
        env.PATH = lib.makeBinPath [pkgs.coreutils];
        # Firefox's glxtest finds GPUs by walking these. Without them it
        # reports none and falls back to software rendering.
        bind.ro = ["/sys/bus/pci" "/sys/class/drm"];
      };
    };
  };
in {
  home.packages = [zotero.config.env];
}
