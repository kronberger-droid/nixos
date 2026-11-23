# A nixpak module, imported by every wrapper here next to gui-base. Not a
# home-manager module, so default.nix does not list it.
#
# gui-base lets an app talk to gvfs and dconf on the session bus, and both
# daemons run outside the sandbox with the user's full reach: gvfs mounts
# sftp:// with the real ~/.ssh and agent, and dconf takes writes to any
# GSettings key. Nothing wrapped here needs either. Files come in through
# the FileChooser portal, and the dconf database itself is not bound, so
# the apps already read defaults. The policy has no "deny"; `see` is the
# weakest there is and allows no calls.
{lib, ...}: {
  dbus.policies = {
    "org.gtk.vfs" = lib.mkForce "see";
    "org.gtk.vfs.*" = lib.mkForce "see";
    "ca.desrt.dconf" = lib.mkForce "see";
  };
}
