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
        # Without these, the dynamic fallback may return a proportional font, breaking cell alignment.
        # Note: "Symbols Nerd Font Mono" only covers Nerd Font icon ranges (PUA),
        # not standard Unicode symbol blocks — don't use it here.
        # SMP emoji (🚀 U+1F680, 🟢 U+1F7E2, …) are mapped to "Noto Emoji" — the monochrome
        # (grayscale) sibling of Noto Color Emoji. They CAN'T be fixed by fontconfig fallback:
        # sugarloaf's per-codepoint discovery (linux.rs:discover_fallback) hints fontconfig with
        # the *primary* family, not "emoji", so the emoji alias in fonts.nix never fires — and
        # once both Noto Emoji and Symbola cover a glyph it's a charset tie decided by fragile
        # ordering. symbol-map is the only deterministic route (Rio 0.4.x has no emoji/extras key).
        # symbol-map is a HARD override (tofu on miss, no fallback), so these ranges are derived
        # from Noto Emoji's own charset; its gaps stay on the existing Symbola fallback. Regen:
        #   fc-query --format='%{charset}\n' NotoEmoji.ttf | tr ' ' '\n' | sort -u \
        #     | awk -F- '{s=strtonum("0x"$1)} s>=0x1F000 && s<=0x1FFFF'
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

          # SMP emoji (U+1F000-1FFFF) → "Noto Emoji" monochrome. Auto-derived from the font's
          # charset (regen command above); gaps are unassigned/non-emoji codepoints that stay
          # on the Symbola fallback. Covers Emoticons, Misc Pictographs, Transport, Supplemental,
          # Extended-A, the colored shapes (🟢🟠🟥 U+1F7E0-1F7EB), and flag regional indicators.
          { start = "1F004"; end = "1F004"; font-family = "Noto Emoji"; }
          { start = "1F0CF"; end = "1F0CF"; font-family = "Noto Emoji"; }
          { start = "1F170"; end = "1F171"; font-family = "Noto Emoji"; }
          { start = "1F17E"; end = "1F17F"; font-family = "Noto Emoji"; }
          { start = "1F18E"; end = "1F18E"; font-family = "Noto Emoji"; }
          { start = "1F191"; end = "1F19A"; font-family = "Noto Emoji"; }
          { start = "1F1E6"; end = "1F1FF"; font-family = "Noto Emoji"; } # regional indicators (flags)
          { start = "1F201"; end = "1F202"; font-family = "Noto Emoji"; }
          { start = "1F21A"; end = "1F21A"; font-family = "Noto Emoji"; }
          { start = "1F22F"; end = "1F22F"; font-family = "Noto Emoji"; }
          { start = "1F232"; end = "1F23A"; font-family = "Noto Emoji"; }
          { start = "1F250"; end = "1F251"; font-family = "Noto Emoji"; }
          { start = "1F300"; end = "1F321"; font-family = "Noto Emoji"; }
          { start = "1F324"; end = "1F393"; font-family = "Noto Emoji"; }
          { start = "1F396"; end = "1F397"; font-family = "Noto Emoji"; }
          { start = "1F399"; end = "1F39B"; font-family = "Noto Emoji"; }
          { start = "1F39E"; end = "1F3F0"; font-family = "Noto Emoji"; }
          { start = "1F3F3"; end = "1F3F5"; font-family = "Noto Emoji"; }
          { start = "1F3F7"; end = "1F4FD"; font-family = "Noto Emoji"; }
          { start = "1F4FF"; end = "1F53D"; font-family = "Noto Emoji"; }
          { start = "1F549"; end = "1F54E"; font-family = "Noto Emoji"; }
          { start = "1F550"; end = "1F567"; font-family = "Noto Emoji"; }
          { start = "1F56F"; end = "1F570"; font-family = "Noto Emoji"; }
          { start = "1F573"; end = "1F57A"; font-family = "Noto Emoji"; }
          { start = "1F587"; end = "1F587"; font-family = "Noto Emoji"; }
          { start = "1F58A"; end = "1F58D"; font-family = "Noto Emoji"; }
          { start = "1F590"; end = "1F590"; font-family = "Noto Emoji"; }
          { start = "1F595"; end = "1F596"; font-family = "Noto Emoji"; }
          { start = "1F5A4"; end = "1F5A5"; font-family = "Noto Emoji"; }
          { start = "1F5A8"; end = "1F5A8"; font-family = "Noto Emoji"; }
          { start = "1F5B1"; end = "1F5B2"; font-family = "Noto Emoji"; }
          { start = "1F5BC"; end = "1F5BC"; font-family = "Noto Emoji"; }
          { start = "1F5C2"; end = "1F5C4"; font-family = "Noto Emoji"; }
          { start = "1F5D1"; end = "1F5D3"; font-family = "Noto Emoji"; }
          { start = "1F5DC"; end = "1F5DE"; font-family = "Noto Emoji"; }
          { start = "1F5E1"; end = "1F5E1"; font-family = "Noto Emoji"; }
          { start = "1F5E3"; end = "1F5E3"; font-family = "Noto Emoji"; }
          { start = "1F5E8"; end = "1F5E8"; font-family = "Noto Emoji"; }
          { start = "1F5EF"; end = "1F5EF"; font-family = "Noto Emoji"; }
          { start = "1F5F3"; end = "1F5F3"; font-family = "Noto Emoji"; }
          { start = "1F5FA"; end = "1F64F"; font-family = "Noto Emoji"; } # Emoticons (😀-🙏)
          { start = "1F680"; end = "1F6C5"; font-family = "Noto Emoji"; } # Transport & Map (🚀)
          { start = "1F6CB"; end = "1F6D2"; font-family = "Noto Emoji"; }
          { start = "1F6D5"; end = "1F6D7"; font-family = "Noto Emoji"; }
          { start = "1F6DC"; end = "1F6E5"; font-family = "Noto Emoji"; }
          { start = "1F6E9"; end = "1F6E9"; font-family = "Noto Emoji"; }
          { start = "1F6EB"; end = "1F6EC"; font-family = "Noto Emoji"; }
          { start = "1F6F0"; end = "1F6F0"; font-family = "Noto Emoji"; }
          { start = "1F6F3"; end = "1F6FC"; font-family = "Noto Emoji"; }
          { start = "1F7E0"; end = "1F7EB"; font-family = "Noto Emoji"; } # colored circles/squares (🟢🟥)
          { start = "1F7F0"; end = "1F7F0"; font-family = "Noto Emoji"; }
          { start = "1F90C"; end = "1F93A"; font-family = "Noto Emoji"; }
          { start = "1F93C"; end = "1F945"; font-family = "Noto Emoji"; }
          { start = "1F947"; end = "1F9FF"; font-family = "Noto Emoji"; } # Supplemental Symbols (🤖🦀)
          { start = "1FA70"; end = "1FA7C"; font-family = "Noto Emoji"; }
          { start = "1FA80"; end = "1FA88"; font-family = "Noto Emoji"; }
          { start = "1FA90"; end = "1FABD"; font-family = "Noto Emoji"; }
          { start = "1FABF"; end = "1FAC5"; font-family = "Noto Emoji"; }
          { start = "1FACE"; end = "1FADB"; font-family = "Noto Emoji"; }
          { start = "1FAE0"; end = "1FAE8"; font-family = "Noto Emoji"; }
          { start = "1FAF0"; end = "1FAF8"; font-family = "Noto Emoji"; }
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
        # `Webgpu` delegates to wgpu, which probes Vulkan → GL → fallback at startup.
        # (Rio 0.4.3 removed the old `Automatic` variant; `Webgpu` is the replacement.)
        # Forcing `Vulkan` segfaulted on launch under Wayland after upgrading to 0.4.0
        # (rio_window::wayland::EventLoop::poll_events_with_timeout). Switch back to
        # `Vulkan` once https://github.com/raphamorim/rio/issues/1530 settles.
        backend = "Webgpu";
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
