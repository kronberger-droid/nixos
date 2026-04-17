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

        # Map Unicode ranges where JetBrainsMono Nerd Font has poor or no coverage
        # to JuliaMono, a mono-metric symbol font that matches terminal cells.
        # Note: "Symbols Nerd Font Mono" only covers Nerd Font icon ranges (PUA),
        # not standard Unicode symbol blocks — don't use it here.
        symbol-map = [
          { start = "2300"; end = "23FF"; font-family = "JuliaMono"; } # Misc Technical (⏺⏱⏵⏸)
          { start = "2600"; end = "26FF"; font-family = "JuliaMono"; } # Misc Symbols (★☀☁☂)
          { start = "2700"; end = "27BF"; font-family = "JuliaMono"; } # Dingbats (✔✘✂)
          { start = "2800"; end = "28FF"; font-family = "JuliaMono"; } # Braille (spinners, btop)
        ];

        regular = {
          family = "JetBrainsMonoNL Nerd Font";
          style = "Normal";
          weight = 500; # Medium — a hair heavier than default 400
        };
        bold = {
          family = "JetBrainsMonoNL Nerd Font";
          style = "Normal";
          weight = 700; # Bold
        };
        italic = {
          family = "JetBrainsMonoNL Nerd Font";
          style = "Italic";
          weight = 500;
        };
        bold-italic = {
          family = "JetBrainsMonoNL Nerd Font";
          style = "Italic";
          weight = 700;
        };
      };

      # Text rendering
      line-height = 1.0; # >1.0 causes mouse selection offset (github.com/raphamorim/rio/issues/1101)
      padding-x = 4;

      # Auto-copy on select (no Ctrl+Shift+C needed)
      copy-on-select = true;

      # Cursor
      cursor = {
        shape = "block";
        blinking = false;
      };

      # Renderer
      renderer = {
        backend = "Vulkan";
        performance = "High";
        disable-unfocused-render = false; # true stops rendering when unfocused, hiding Helix/tail-like output until refocus
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
