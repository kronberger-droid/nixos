{
  pkgs,
  config,
  ...
}: {
  programs.alacritty = {
    enable = true;
    settings = {
      # Window settings
      window = {
        opacity = 1.0;
        decorations = "full";
        startup_mode = "Windowed";
      };

      # Scrolling
      scrolling = {
        history = 10000;
        multiplier = 3;
      };

      # Font configuration
      font = {
        size = 11.0;
        normal = {
          family = "monospace";
          style = "Regular";
        };
        bold = {
          family = "monospace";
          style = "Bold";
        };
        italic = {
          family = "monospace";
          style = "Italic";
        };
      };

      # Colors - matching kitty base16 scheme
      colors = {
        primary = {
          background = "#${config.scheme.base00}";
          foreground = "#${config.scheme.base05}";
        };

        cursor = {
          text = "#${config.scheme.base00}";
          cursor = "#${config.scheme.base05}";
        };

        selection = {
          text = "#${config.scheme.base05}";
          background = "#${config.scheme.base02}";
        };

        # Normal colors
        normal = {
          black = "#${config.scheme.base00}";
          red = "#${config.scheme.base08}";
          green = "#${config.scheme.base0B}";
          yellow = "#${config.scheme.base0A}";
          blue = "#${config.scheme.base0D}";
          magenta = "#${config.scheme.base0E}";
          cyan = "#${config.scheme.base0C}";
          white = "#${config.scheme.base05}";
        };

        # Bright colors
        bright = {
          black = "#${config.scheme.base03}";
          red = "#${config.scheme.base09}";
          green = "#${config.scheme.base0B}";
          yellow = "#${config.scheme.base0A}";
          blue = "#${config.scheme.base0D}";
          magenta = "#${config.scheme.base0E}";
          cyan = "#${config.scheme.base0C}";
          white = "#${config.scheme.base07}";
        };
      };

      # Cursor
      cursor = {
        style = {
          shape = "Block";
          blinking = "Off";
        };
      };

      # Shell
      terminal.shell = {
        program = "${pkgs.nushell}/bin/nu";
      };

      # Mouse
      mouse = {
        hide_when_typing = false;
      };

      # Selection
      selection = {
        save_to_clipboard = true;
      };
    };
  };
}
