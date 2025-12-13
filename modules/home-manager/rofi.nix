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
    "rofi/shared/colors.rasi".text = with config.scheme; ''
      /**
       * Colors using base16 scheme variables for consistency
       * Following base16 conventions:
       * - base00: Default background
       * - base01: Alternate background
       * - base02: Selection background
       * - base05: Default text
       * - base0A: Warning
       * - base09: Urgent
       * - base08: Error
       **/

      * {
          base00:         #${base00};
          base01:         #${base01};
          base02:         #${base02};
          base03:         #${base03};
          base04:         #${base04};
          base05:         #${base05};
          base06:         #${base06};
          base07:         #${base07};
          base08:         #${base08};
          base09:         #${base09};
          base0A:         #${base0A};
          base0B:         #${base0B};
          base0C:         #${base0C};
          base0D:         #${base0D};
          base0E:         #${base0E};
          base0F:         #${base0F};
          base00E6:       #${base00}E6;
          base01E6:       #${base01}E6;
          base09E6:       #${base09}E6;
          base0DE6:       #${base0D}E6;
          base0FFF:       #${base0F}FF;

          background:     @base00E6; /* Default background with 90% opacity */
          background-alt: @base01E6; /* Alternate background with 90% opacity */
          foreground:     @base05; /* Default text */
          selected:       @base0FFF; /* Brown accent (base0F) - 100% opacity */
          active:         @base0DE6; /* Blue - 90% opacity */
          urgent:         @base09E6; /* Urgent (base09) - 90% opacity */
      }
    '';
    "rofi/shared/fonts.rasi".source = ./rofi/shared/fonts.rasi;
  };
}
