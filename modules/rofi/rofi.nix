{config, lib, pkgs, ...}:{
  programs.rofi = {
    enable = true;
    theme = "${config.xdg.configHome}/rofi/launcher/style-2.rasi";
  };

  xdg.configFile."rofi/powermenu/style-1.rasi".source = ./powermenu/style-1.rasi;
  xdg.configFile."rofi/powermenu/powermenu.sh".source = ./powermenu/powermenu.sh;
  xdg.configFile."rofi/launcher/style-2.rasi".source = ./launcher/style-2.rasi;
  xdg.configFile."rofi/shared/colors.rasi".source = ./shared/colors.rasi;
  xdg.configFile."rofi/shared/fonts.rasi".source = ./shared/fonts.rasi;
}
