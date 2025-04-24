{config, lib, pkgs, ...}:{
  programs.rofi = {
    enable = true;
    package = pkgs.rofi-wayland;
    theme = "${config.xdg.configHome}/rofi/launcher/style-2.rasi";
  };

  xdg.configFile."rofi/powermenu/style-1.rasi".source = ./rofi/powermenu/style-1.rasi;
  xdg.configFile."rofi/powermenu/powermenu.sh".source = ./rofi/powermenu/powermenu.sh;
  xdg.configFile."rofi/launcher/style-2.rasi".source = ./rofi/launcher/style-2.rasi;
  xdg.configFile."rofi/shared/colors.rasi".source = ./rofi/shared/colors.rasi;
  xdg.configFile."rofi/shared/fonts.rasi".source = ./rofi/shared/fonts.rasi;
}
