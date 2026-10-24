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
      imports = with inputs.nixpak.nixpakModules; [gui-base network];

      app.package = pkgs.zotero;
      flatpak.appId = "org.zotero.Zotero";

      # gui-base bundles its own mesa; the host's driver matches the kernel
      # and is already in the store.
      gpu.provider = lib.mkForce "nixos";

      # Binds the host's /etc/localtime. Without it there is none in the
      # sandbox and every timestamp shows in UTC.
      timeZone.enable = true;

      dbus.policies = {
        "org.freedesktop.Notifications" = "talk";
      };

      bubblewrap = {
        bind.rw = [
          # The library and attachments (extensions.zotero.dataDir).
          (sloth.concat' sloth.homeDir "/Zotero")
          # The profile, which also holds the sync login.
          (sloth.mkdir (sloth.concat' sloth.homeDir "/.zotero"))
          (sloth.concat' sloth.homeDir "/Downloads")
          # A private /tmp, see signal.nix.
          [(sloth.mkdir (sloth.concat' sloth.appCacheDir "/tmp")) "/tmp"]
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
