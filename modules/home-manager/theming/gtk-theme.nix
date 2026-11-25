# The GTK theme, as a function of pkgs and not a home-manager module, so
# default.nix does not list it. theme.nix sets it for the session, and
# apps/nixpak-common.nix, a nixpak module that cannot read home-manager's
# config, puts the same package on the sandboxes' XDG_DATA_DIRS.
pkgs: {
  # libadwaita's look for GTK3, so GTK3 and GTK4 apps match. It also takes
  # its colors from the names libadwaita uses, which is what lets the one
  # block in theme.nix recolor both from the base16 scheme.
  name = "adw-gtk3-dark";
  package = pkgs.adw-gtk3;
}
