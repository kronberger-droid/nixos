{
  config,
  pkgs,
  ...
}: let
  gtkTheme = import ./gtk-theme.nix pkgs;

  # The scheme, under the color names adw-gtk3 (GTK3) and libadwaita (GTK4)
  # both build their palettes from. Loaded after the theme, as the user's
  # gtk.css, so these win. What is not named here keeps Adwaita's value,
  # most of which derive from the ones that are.
  #
  # Window and view share base00: Adwaita sets the view a shade darker, and
  # the scheme has nothing below base00 to give it.
  adwaitaColors = with config.scheme; ''
    @define-color window_bg_color #${base00};
    @define-color window_fg_color #${base05};
    @define-color view_bg_color #${base00};
    @define-color view_fg_color #${base05};
    @define-color headerbar_bg_color #${base01};
    @define-color headerbar_fg_color #${base05};
    @define-color headerbar_border_color #${base05};
    @define-color sidebar_bg_color #${base01};
    @define-color sidebar_fg_color #${base05};
    @define-color sidebar_backdrop_color #${base01};
    @define-color secondary_sidebar_bg_color #${base01};
    @define-color secondary_sidebar_fg_color #${base05};
    @define-color secondary_sidebar_backdrop_color #${base01};
    @define-color card_fg_color #${base05};
    @define-color dialog_bg_color #${base01};
    @define-color dialog_fg_color #${base05};
    @define-color popover_bg_color #${base01};
    @define-color popover_fg_color #${base05};
    @define-color thumbnail_bg_color #${base02};
    @define-color thumbnail_fg_color #${base05};
    @define-color accent_color #${base0D};
    @define-color accent_bg_color #${base0D};
    @define-color accent_fg_color #${base00};
    @define-color destructive_bg_color #${base08};
    @define-color destructive_fg_color #${base07};
    @define-color error_bg_color #${base08};
    @define-color error_fg_color #${base07};
    @define-color success_bg_color #${base0B};
    @define-color success_fg_color #${base00};
    @define-color warning_bg_color #${base0A};
    @define-color warning_fg_color #${base00};
  '';
in {
  qt = {
    enable = true;
    platformTheme.name = "gtk3";
  };

  home.pointerCursor = {
    enable = true;
    gtk.enable = true;
    # Adwaita's cursors and icons are one package, and the one the nixpak
    # sandboxes already have on their XCURSOR_PATH and XDG_DATA_DIRS
    # (gui-base), so apps in them load the same ones.
    package = pkgs.adwaita-icon-theme;
    name = "Adwaita";
    # The smallest size the theme ships.
    size = 24;
  };

  gtk = {
    enable = true;
    gtk4.theme = null;
    theme = gtkTheme;
    # Not Adwaita's icons: GTK draws an emblem at half the icon's size, and
    # Adwaita's fill their whole canvas, so the symlink arrow covered a
    # quarter of every folder in Nemo. Qogir's leave a margin.
    iconTheme = {
      name = "Qogir";
      package = pkgs.qogir-icon-theme;
    };
    gtk3.extraCss = adwaitaColors;
    gtk4.extraCss = adwaitaColors;
    gtk3.extraConfig.gtk-application-prefer-dark-theme = true;
    gtk4.extraConfig.gtk-application-prefer-dark-theme = true;
  };

  dconf.settings."org/gnome/desktop/interface" = {
    color-scheme = "prefer-dark";
    gtk-theme = gtkTheme.name;
  };
}
