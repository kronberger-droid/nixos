{
  pkgs,
  config,
  ...
}: {
  programs.rio = {
    enable = true;
    settings = {
      # Font configuration
      fonts = {
        family = "JetBrainsMono Nerd Font";
        size = 14;
      };

      # Window settings
      window = {
        opacity = 1.0;
        blur = false;
      };

      # Disable quit confirmation
      confirm-before-quit = false;

      # Navigation
      navigation = {
        mode = "Plain"; # No tabs UI since we want it simple
      };

      # Theme - using base16 scheme to match Kitty
      colors = {
        background = "#${config.scheme.base00}";
        foreground = "#${config.scheme.base05}";
        cursor = "#${config.scheme.base05}";
        selection-background = "#${config.scheme.base02}";
        selection-foreground = "#${config.scheme.base05}";

        # ANSI colors
        black = "#${config.scheme.base00}";
        red = "#${config.scheme.base08}";
        green = "#${config.scheme.base0B}";
        yellow = "#${config.scheme.base0A}";
        blue = "#${config.scheme.base0D}";
        magenta = "#${config.scheme.base0E}";
        cyan = "#${config.scheme.base0C}";
        white = "#${config.scheme.base05}";

        # Bright ANSI colors
        light-black = "#${config.scheme.base03}";
        light-red = "#${config.scheme.base09}";
        light-green = "#${config.scheme.base0B}";
        light-yellow = "#${config.scheme.base0A}";
        light-blue = "#${config.scheme.base0D}";
        light-magenta = "#${config.scheme.base0E}";
        light-cyan = "#${config.scheme.base0C}";
        light-white = "#${config.scheme.base07}";

        # UI elements
        tabs = "#${config.scheme.base00}";
        tabs-active = "#${config.scheme.base0D}";
        vi-cursor = "#${config.scheme.base05}";
      };
    };
  };
}
