# Apps that run better as a Flatpak than from a nixpak wrapper: they bundle
# their own toolkits and expect the Flatpak runtime around them. nix-flatpak
# installs them per user from a systemd unit on activation, so the bits come
# from the remotes below, not the store, and are not covered by rollbacks.
#
# The system side (services.flatpak.enable) is in system/desktop/desktop.nix;
# this module turns itself on from that.
{pkgs, ...}: let
  # The key Ladybird signs its repository with, as the `GPGKey=` line of
  # https://flatpak.ladybird.org/ladybird.flatpakrepo has it. Pinned here
  # and the remote added by its bare URL, so the key is not whatever that
  # file says on the day the remote is first set up.
  # Fingerprint 9436 EDD8 A323 02AD 5B9B  C80F D941 A9B5 3C44 8496.
  ladybirdKey = pkgs.runCommand "ladybird-flatpak.gpg" {} ''
    base64 -d > $out <<'EOF'
    mDMEautPJRYJKwYBBAHaRw8BAQdAt/rmt5fOquYPXrjTiPaNmaWXeG2xkj4WjjAEF1EP67S0G0xhZHliaXJkIEZsYXRwYWsgcmVwb3NpdG9yeYivBBMWCgBXFiEElDbt2KMjAq1bm8gP2UGptTxEhJYFAmrsbFMbFIAAAAAABAAObWFudTIsMi41KzEuMTIsMCwzAhsDBQsJCAcCAiICBhUKCQgLAgQWAgMBAh4HAheAAAoJENlBqbU8RISWqqIA/3cNWn3aHNQjTY9wDPUnSncfqZsBuebb2NZh9borxhOYAP4o0hwUZiIstc8X5iTWh5z1YRGkd0qDtBerck3u52jeAA==
    EOF
  '';
in {
  services.flatpak = {
    # Setting this replaces the module's default, hence Flathub again.
    remotes = [
      {
        name = "flathub";
        location = "https://dl.flathub.org/repo/flathub.flatpakrepo";
      }
      {
        name = "ladybird";
        location = "https://flatpak.ladybird.org/repo/";
        gpg-import = "${ladybirdKey}";
      }
    ];

    packages = [
      # The project's own repository, which carries the releases; nixpkgs
      # has a snapshot that trails them and Flathub has no Ladybird. The
      # branch is the remote's default, `stable`. Its KDE runtime comes
      # from Flathub.
      {
        appId = "org.ladybird.Ladybird";
        origin = "ladybird";
      }
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
        # The notes tree read-only: a macro that could write there could
        # drop a plugin into the vault, which Obsidian runs with network and
        # ~/Projects.
        filesystems = ["!host" "!/tmp" "xdg-documents" "xdg-documents/notes:ro" "xdg-download"];
      };
      # Ladybird asks for the whole session bus. That is no sandbox: the
      # systemd user manager is on it and starts anything, and so are gvfs
      # and the Secret Service. Without the socket Flatpak puts its
      # filtering proxy in between, which still lets the portals through
      # (file chooser, opening links), and the manifest's own three `talk`
      # names keep applying. What is left is the network, Downloads and
      # the GPU.
      "org.ladybird.Ladybird".Context.sockets = ["!session-bus"];
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

    # The remotes ship security fixes on their own schedule, so pull them weekly
    # rather than only when the config changes.
    update.auto = {
      enable = true;
      onCalendar = "weekly";
    };
  };
}
