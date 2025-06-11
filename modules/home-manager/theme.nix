{ pkgs, ... }:
{
  qt.enable = true;

  home.pointerCursor = {
    gtk.enable = true;
    package = pkgs.quintom-cursor-theme;
    name = "Quintom_Ink";
    size = 22;
  };
  
  gtk = {
    enable = true;
    theme = {
      name = "Fluent-round-Dark-compact";
      package = pkgs.fluent-gtk-theme.override {
        themeVariants = [ "default" ];
        colorVariants = [ "dark" ];
        sizeVariants = [ "compact" ];
        tweaks = [ "round" ];
      };
    };
    iconTheme = {
      name = "Qogir";
      package = pkgs.qogir-icon-theme;
    };
  };
}
