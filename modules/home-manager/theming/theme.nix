{pkgs, ...}: let
  gtkTheme = import ./gtk-theme.nix pkgs;
in {
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
    theme = gtkTheme;
    iconTheme = {
      name = "Qogir";
      package = pkgs.qogir-icon-theme;
    };
    gtk3.extraConfig.gtk-application-prefer-dark-theme = true;
    gtk4.extraConfig.gtk-application-prefer-dark-theme = true;
  };

  dconf.settings."org/gnome/desktop/interface" = {
    color-scheme = "prefer-dark";
    gtk-theme = gtkTheme.name;
  };
}
