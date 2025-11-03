{ config, pkgs, ... }: {
  programs.rofi = {
    enable = true;
    package = pkgs.rofi;
    theme = "${config.xdg.configHome}/rofi/launcher/style-2.rasi";
  };

  xdg.configFile = {
    "rofi/powermenu/style-1.rasi".source = ./rofi/powermenu/style-1.rasi;
    "rofi/powermenu/powermenu.sh".source = ./rofi/powermenu/powermenu.sh;
    "rofi/launcher/style-2.rasi".source = ./rofi/launcher/style-2.rasi;
    "rofi/shared/colors.rasi".source = ./rofi/shared/colors.rasi;
    "rofi/shared/fonts.rasi".source = ./rofi/shared/fonts.rasi;
  };
}
