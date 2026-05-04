{pkgs, ...}: {
  qt = {
    enable = true;
    platformTheme.name = "gtk3";
  };

  home.pointerCursor = {
    gtk.enable = true;
    package = pkgs.quintom-cursor-theme;
    name = "Quintom_Ink";
    size = 22;
  };

  gtk = {
    enable = true;
    gtk4.theme = null;
    theme = {
      name = "Fluent-round-Dark-compact";
      package = pkgs.fluent-gtk-theme.override {
        themeVariants = ["default"];
        colorVariants = ["dark"];
        sizeVariants = ["compact"];
        tweaks = ["round"];
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
    gtk-theme = "Fluent-round-Dark-compact";
  };
}
