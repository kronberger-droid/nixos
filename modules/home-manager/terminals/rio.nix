{config, ...}: {
  programs.rio = {
    enable = true;
    settings = {
      # Font configuration
      fonts = {
        size = 15;
        hinting = true;
        use-drawable-chars = true;
        features = []; # JetBrainsMonoNL has no ligatures by design

        # Map Unicode ranges missing from Nerd Font to Noto Sans Symbols 2
        symbol-map = [
          { start = "2300"; end = "23FF"; font-family = "Noto Sans Symbols 2"; } # Misc Technical (⏱⏵⏸)
          { start = "2600"; end = "26FF"; font-family = "Noto Sans Symbols 2"; } # Misc Symbols (☀☁☂)
          { start = "2700"; end = "27BF"; font-family = "Noto Sans Symbols 2"; } # Dingbats (✔✘✂)
          { start = "2800"; end = "28FF"; font-family = "Noto Sans Symbols 2"; } # Braille patterns
        ];

        regular = {
          family = "JetBrainsMonoNL Nerd Font";
          style = "Normal";
          weight = 600;
        };
        bold = {
          family = "JetBrainsMonoNL Nerd Font";
          style = "Normal";
          weight = 800;
        };
        italic = {
          family = "JetBrainsMonoNL Nerd Font";
          style = "Italic";
          weight = 600;
        };
        bold-italic = {
          family = "JetBrainsMonoNL Nerd Font";
          style = "Italic";
          weight = 800;
        };
      };

      # Text rendering
      line-height = 1.0; # >1.0 causes mouse selection offset (github.com/raphamorim/rio/issues/1101)
      padding-x = 4;

      # Hide mouse cursor while typing
      hide-mouse-cursor-when-typing = true;

      # Auto-copy on select (no Ctrl+Shift+C needed)
      copy-on-select = true;

      # Cursor
      cursor = {
        shape = "block";
        blinking = true;
        blinking-interval = 600;
      };

      # Renderer
      renderer = {
        backend = "Vulkan";
        performance = "High";
        disable-unfocused-render = true;
      };

      # Window settings
      window = {
        opacity = 1.0;
        blur = false;
      };

      # Disable quit confirmation
      confirm-before-quit = false;

      # Navigation — Plain since we use niri/zellij for splits/tabs
      navigation = {
        mode = "Plain";
        use-split = false;
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
