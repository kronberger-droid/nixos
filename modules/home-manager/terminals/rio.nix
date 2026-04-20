{config, ...}: {
  programs.rio = {
    enable = true;
    settings = {
      # Font configuration
      # Rio's `size` is in pixels, not points; 16px ≈ 11pt at ~96 DPI.
      fonts = {
        size = 16;
        hinting = true;
        use-drawable-chars = true;
        features = [];

        # Only remap codepoints NOT covered by JetBrainsMonoNL Nerd Font.
        # Ranges derived from `fc-match --format=%{family} "...:charset=CP"` per codepoint
        # in Misc Technical, Misc Symbols, Dingbats, and Braille blocks.
        # Without these, fontconfig falls back to DejaVu Sans (proportional), breaking cell alignment.
        # Note: "Symbols Nerd Font Mono" only covers Nerd Font icon ranges (PUA),
        # not standard Unicode symbol blocks — don't use it here.
        symbol-map = [
          # Misc Technical (U+2300-23FF) — JBM covers ~45%, remap the gaps
          { start = "2300"; end = "2301"; font-family = "JuliaMono"; }
          { start = "2306"; end = "2307"; font-family = "JuliaMono"; }
          { start = "230C"; end = "2317"; font-family = "JuliaMono"; }
          { start = "2319"; end = "231B"; font-family = "JuliaMono"; }
          { start = "2320"; end = "2323"; font-family = "JuliaMono"; }
          { start = "2327"; end = "2327"; font-family = "JuliaMono"; }
          { start = "2329"; end = "232A"; font-family = "JuliaMono"; }
          { start = "232C"; end = "2335"; font-family = "JuliaMono"; }
          { start = "237B"; end = "2388"; font-family = "JuliaMono"; }
          { start = "238C"; end = "2394"; font-family = "JuliaMono"; }
          { start = "2396"; end = "239A"; font-family = "JuliaMono"; }
          { start = "23AE"; end = "23CD"; font-family = "JuliaMono"; }
          { start = "23CF"; end = "23FA"; font-family = "JuliaMono"; } # btop media controls ⏺⏱⏵⏸
          { start = "23FF"; end = "23FF"; font-family = "JuliaMono"; }
          # Misc Symbols (U+2600-26FF) — JBM covers ~3%, remap the gaps (★☀☁☂)
          { start = "2600"; end = "262F"; font-family = "JuliaMono"; }
          { start = "2631"; end = "2664"; font-family = "JuliaMono"; }
          { start = "2666"; end = "266C"; font-family = "JuliaMono"; }
          { start = "266E"; end = "266E"; font-family = "JuliaMono"; }
          { start = "2670"; end = "2686"; font-family = "JuliaMono"; }
          { start = "2688"; end = "269F"; font-family = "JuliaMono"; }
          { start = "26A2"; end = "26FF"; font-family = "JuliaMono"; }
          # Dingbats (U+2700-27BF) — JBM covers ~7%, remap the gaps (✔✘✂)
          # Preserves JBM coverage of U+276C-2771 including ❯ (starship prompt)
          { start = "2700"; end = "2712"; font-family = "JuliaMono"; }
          { start = "2714"; end = "2714"; font-family = "JuliaMono"; }
          { start = "2716"; end = "2716"; font-family = "JuliaMono"; }
          { start = "2718"; end = "2735"; font-family = "JuliaMono"; }
          { start = "2737"; end = "276B"; font-family = "JuliaMono"; }
          { start = "2772"; end = "2793"; font-family = "JuliaMono"; }
          { start = "2795"; end = "279B"; font-family = "JuliaMono"; }
          { start = "279F"; end = "27BF"; font-family = "JuliaMono"; }
          # Braille Patterns (U+2800-28FF) — JBM has 0 coverage, remap entire block (spinners, btop)
          { start = "2800"; end = "28FF"; font-family = "JuliaMono"; }
        ];

        regular = {
          family = "JetBrainsMonoNL Nerd Font";
          style = "Normal";
          weight = 500; # Medium — a hair heavier than default 400
        };
        bold = {
          family = "JetBrainsMonoNL Nerd Font";
          style = "Normal";
          weight = 700;
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
