# The GTK theme, as a function of pkgs and not a home-manager module, so
# default.nix does not list it. theme.nix sets it for the session, and
# apps/nixpak-common.nix, a nixpak module that cannot read home-manager's
# config, puts the same package on the sandboxes' XDG_DATA_DIRS.
pkgs: {
  # Colloid, not Fluent: nixpkgs dropped gtk-engine-murrine, which took
  # fluent-gtk-theme (and most other classic themes) with it. Same
  # upstream author and the same override arguments; Fluent's "round"
  # tweak has no counterpart since Colloid is rounded by default.
  name = "Colloid-Dark-Compact";
  package = pkgs.colloid-gtk-theme.override {
    themeVariants = ["default"];
    colorVariants = ["dark"];
    sizeVariants = ["compact"];
  };
}
