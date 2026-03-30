{config, ...}: {
  programs.rio = {
    enable = true;
    settings = {
      # Font configuration
      fonts = {
        size = 14;
        hinting = true;
        use-drawable-chars = true;
        features = ["calt" "liga"]; # ligatures and contextual alternates

        regular = {
          family = "JetBrainsMono Nerd Font";
          style = "Normal";
          weight = 400;
        };
        bold = {
          family = "JetBrainsMono Nerd Font";
          style = "Normal";
          weight = 700;
        };
        italic = {
          family = "JetBrainsMono Nerd Font";
          style = "Italic";
          weight = 400;
        };
        bold-italic = {
          family = "JetBrainsMono Nerd Font";
          style = "Italic";
          weight = 700;
        };
      };

      # Text rendering
      line-height = 1.05;
      padding-x = 4;

      # Renderer
      renderer = {
        backend = "Vulkan";
        performance = "High";
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
        mode = "Plain";
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
