# A nixpak module, imported by every wrapper here next to gui-base. Not a
# home-manager module, so default.nix does not list it. What all the
# sandboxes share lives here; each wrapper adds its own profile directory,
# bus names and quirks.
{
  lib,
  pkgs,
  sloth,
  ...
}: let
  gtkTheme = import ../theming/gtk-theme.nix pkgs;
in {
  # gui-base bundles its own mesa; the host's driver matches the kernel
  # and is already in the store.
  gpu.provider = lib.mkForce "nixos";

  # Binds the host's /etc/localtime. Without it there is none in the
  # sandbox and every timestamp shows in UTC.
  timeZone.enable = true;

  # gui-base lets an app talk to gvfs and dconf on the session bus, and both
  # daemons run outside the sandbox with the user's full reach: gvfs mounts
  # sftp:// with the real ~/.ssh and agent, and dconf takes writes to any
  # GSettings key. Nothing wrapped here needs either. Files come in through
  # the FileChooser portal, and the dconf database itself is not bound, so
  # the apps already read defaults. The policy has no "deny"; `see` is the
  # weakest there is and allows no calls.
  dbus.policies = {
    "org.gtk.vfs" = lib.mkForce "see";
    "org.gtk.vfs.*" = lib.mkForce "see";
    "ca.desrt.dconf" = lib.mkForce "see";
  };

  bubblewrap = {
    bind.rw = [
      # The one folder every app shares with the user, and so with each
      # other: whatever one of them writes here, another may open.
      (sloth.concat' sloth.homeDir "/Downloads")
      # A private /tmp. The mkdir also creates the app cache dir that
      # gui-base maps onto ~/.cache: it binds with --bind-try, which
      # silently skips a missing source.
      [(sloth.mkdir (sloth.concat' sloth.appCacheDir "/tmp")) "/tmp"]
    ];
    # The session's environment is inherited whole. Credentials that may be
    # in it are blanked by name; this nixpak cannot unset one. Not
    # `clearEnv`: that needs the full list of what each toolkit reads, and
    # a miss is an app that does not start.
    env = {
      # gui-base binds ~/.config/gtk-3.0, so GTK in the sandbox reads the
      # theme's name, but its XDG_DATA_DIRS holds no themes. GTK then drops
      # the dark variant along with the name and draws light Adwaita, which
      # is what an app's own file picker and dialogs came up in. gui-base's
      # two entries are restated because this replaces its value.
      XDG_DATA_DIRS = lib.mkForce (lib.makeSearchPath "share" [
        gtkTheme.package
        pkgs.adwaita-icon-theme
        pkgs.shared-mime-info
      ]);
      GH_TOKEN = "";
      GITHUB_TOKEN = "";
      GITHUB_PERSONAL_ACCESS_TOKEN = "";
    };
  };
}
