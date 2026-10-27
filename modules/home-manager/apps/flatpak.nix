# Apps that run better from Flathub than from a nixpak wrapper: they bundle
# their own toolkits and expect the Flatpak runtime around them. nix-flatpak
# installs them per user from a systemd unit on activation, so the bits come
# from Flathub, not the store, and are not covered by rollbacks.
#
# The system side (services.flatpak.enable) is in system/desktop/desktop.nix;
# this module turns itself on from that.
_: {
  services.flatpak = {
    packages = [
      # The nixpak attempt crashed inside its bundled Qt and CEF once nested
      # in a second sandbox.
      "org.onlyoffice.desktopeditors"
      # Its home is a private ~/.var/app/com.valvesoftware.Steam, so games do
      # not see ~/.ssh or the rest of $HOME. Client flags and the Terraria
      # fix are in steam.nix.
      "com.valvesoftware.Steam"
      # Under nixpak the window stayed grey, the renderer failing inside
      # Electron's own init. The likely cause is nixpkgs' Electron, newer
      # than the one Obsidian ships for; Flathub bundles the matching one.
      "md.obsidian.Obsidian"
    ];

    overrides = {
      # Cursor themes from home.pointerCursor are symlinks into the store,
      # which Flatpak does not mount, and the runtimes leave XCURSOR_PATH
      # empty, so X11 apps fell back to the core cursor. The store is
      # world-readable on the host anyway; read-only it adds nothing an app
      # could not already learn.
      global = {
        Context.filesystems = ["/nix/store:ro"];
        Environment.XCURSOR_PATH = "/run/host/user-share/icons:/run/host/share/icons";
      };
      # Flathub grants filesystem=host and the network. It parses untrusted
      # documents and runs their macros and plugins, so it gets neither:
      # only the folders documents live in, and no way to send anything.
      "org.onlyoffice.desktopeditors".Context = {
        shared = ["!network"];
        filesystems = ["!host" "!/tmp" "xdg-documents" "xdg-download"];
      };
      # Non-Steam games added from Downloads otherwise come in through the
      # file chooser portal, which exports the .exe alone under
      # /run/user/<uid>/doc, so the game starts without its data and exits.
      # Writable, since many keep saves and config beside the exe.
      "com.valvesoftware.Steam".Context.filesystems = ["xdg-download"];
      # Flathub grants all of $HOME, removable media, the SSH agent and the
      # Secret Service. Community plugins are unaudited JS with the app's
      # full reach, and BRAT installs them straight from GitHub, so the reach
      # is cut to where vaults live: the notes tree and ~/Projects. Network
      # stays for BRAT and plugin updates; sync is Syncthing's job.
      "md.obsidian.Obsidian" = {
        Context = {
          filesystems = [
            "!home"
            "!/media"
            "!/mnt"
            "!/run/media"
            "!xdg-run/gnupg"
            "~/Documents/notes"
            "~/Projects"
            "xdg-download"
          ];
          sockets = ["!ssh-auth"];
        };
        "Session Bus Policy"."org.freedesktop.secrets" = "none";
      };
    };

    # Flathub ships security fixes on its own schedule, so pull them weekly
    # rather than only when the config changes.
    update.auto = {
      enable = true;
      onCalendar = "weekly";
    };
  };
}
