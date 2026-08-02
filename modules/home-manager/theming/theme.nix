{pkgs, ...}: {
  qt = {
    enable = true;
    platformTheme.name = "gtk3";
  };

  home.pointerCursor = {
    enable = true;
    gtk.enable = true;
    package = pkgs.quintom-cursor-theme;
    name = "Quintom_Ink";
    size = 22;
  };

  gtk = {
    enable = true;
    gtk4.theme = null;
    theme = {
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
    };
    iconTheme = {
      name = "Qogir";
      package = pkgs.qogir-icon-theme;
    };
    gtk3.extraConfig.gtk-application-prefer-dark-theme = true;
    gtk4.extraConfig.gtk-application-prefer-dark-theme = true;
  };

  dconf.settings."org/gnome/desktop/interface" = {
    color-scheme = "prefer-dark";
    gtk-theme = "Colloid-Dark-Compact";
  };
}
