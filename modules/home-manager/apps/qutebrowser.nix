{config, pkgs, ...}: let
  s = config.scheme;
in {
  programs.qutebrowser = {
    enable = true;
    loadAutoconfig = true;

    settings = {
      # Content
      content = {
        blocking.method = "both";
        javascript.clipboard = "access";
      };

      # Prefer dark mode in websites that support it
      colors.webpage = {
        preferred_color_scheme = "dark";
        darkmode.enabled = true;
      };

      # Completion bar (Ctrl+O, :commands)
      colors.completion = {
        fg = "#${s.base05}";
        odd.bg = "#${s.base00}";
        even.bg = "#${s.base01}";
        category = {
          fg = "#${s.base0D}";
          bg = "#${s.base00}";
          border = {
            top = "#${s.base00}";
            bottom = "#${s.base00}";
          };
        };
        item.selected = {
          fg = "#${s.base07}";
          bg = "#${s.base02}";
          border = {
            top = "#${s.base02}";
            bottom = "#${s.base02}";
          };
          match.fg = "#${s.base0B}";
        };
        match.fg = "#${s.base0B}";
        scrollbar = {
          fg = "#${s.base04}";
          bg = "#${s.base00}";
        };
      };

      # Context menu
      colors.contextmenu = {
        menu = {
          fg = "#${s.base05}";
          bg = "#${s.base00}";
        };
        selected = {
          fg = "#${s.base07}";
          bg = "#${s.base02}";
        };
        disabled = {
          fg = "#${s.base03}";
          bg = "#${s.base01}";
        };
      };

      # Downloads bar
      colors.downloads = {
        bar.bg = "#${s.base00}";
        start = {
          fg = "#${s.base00}";
          bg = "#${s.base0D}";
        };
        stop = {
          fg = "#${s.base00}";
          bg = "#${s.base0B}";
        };
        error.fg = "#${s.base08}";
      };

      # Hints (the labels when pressing f)
      colors.hints = {
        fg = "#${s.base00}";
        bg = "#${s.base0A}";
        match.fg = "#${s.base0B}";
      };

      # Keyhint widget
      colors.keyhint = {
        fg = "#${s.base05}";
        suffix.fg = "#${s.base0A}";
        bg = "#${s.base00}";
      };

      # Messages
      colors.messages = {
        error = {
          fg = "#${s.base00}";
          bg = "#${s.base08}";
          border = "#${s.base08}";
        };
        warning = {
          fg = "#${s.base00}";
          bg = "#${s.base0A}";
          border = "#${s.base0A}";
        };
        info = {
          fg = "#${s.base05}";
          bg = "#${s.base00}";
          border = "#${s.base00}";
        };
      };

      # Prompts
      colors.prompts = {
        fg = "#${s.base05}";
        bg = "#${s.base01}";
        border = "#${s.base01}";
        selected = {
          fg = "#${s.base07}";
          bg = "#${s.base02}";
        };
      };

      # Status bar
      colors.statusbar = {
        normal = {
          fg = "#${s.base05}";
          bg = "#${s.base00}";
        };
        insert = {
          fg = "#${s.base00}";
          bg = "#${s.base0B}";
        };
        passthrough = {
          fg = "#${s.base00}";
          bg = "#${s.base0C}";
        };
        command = {
          fg = "#${s.base05}";
          bg = "#${s.base00}";
        };
        caret = {
          fg = "#${s.base00}";
          bg = "#${s.base0E}";
        };
        url = {
          fg = "#${s.base05}";
          success.http.fg = "#${s.base0B}";
          success.https.fg = "#${s.base0B}";
          error.fg = "#${s.base08}";
          warn.fg = "#${s.base0A}";
          hover.fg = "#${s.base0C}";
        };
        progress.bg = "#${s.base0D}";
      };

      # Tabs
      colors.tabs = {
        bar.bg = "#${s.base00}";
        indicator = {
          start = "#${s.base0D}";
          stop = "#${s.base0B}";
          error = "#${s.base08}";
        };
        odd = {
          fg = "#${s.base04}";
          bg = "#${s.base00}";
        };
        even = {
          fg = "#${s.base04}";
          bg = "#${s.base00}";
        };
        selected = {
          odd = {
            fg = "#${s.base05}";
            bg = "#${s.base02}";
          };
          even = {
            fg = "#${s.base05}";
            bg = "#${s.base02}";
          };
        };
        pinned = {
          odd = {
            fg = "#${s.base0B}";
            bg = "#${s.base00}";
          };
          even = {
            fg = "#${s.base0B}";
            bg = "#${s.base00}";
          };
          selected = {
            odd = {
              fg = "#${s.base05}";
              bg = "#${s.base02}";
            };
            even = {
              fg = "#${s.base05}";
              bg = "#${s.base02}";
            };
          };
        };
      };

      # Hints appearance
      hints = {
        border = "1px solid #${s.base00}";
        radius = 3;
      };

      # Fonts
      fonts = {
        default_family = "monospace";
        default_size = "10pt";
      };

      # Tab behavior
      tabs = {
        position = "top";
        show = "multiple";
        last_close = "close";
      };

      # Scrolling
      scrolling.smooth = true;

      # URL settings
      url = {
        default_page = "about:blank";
        start_pages = ["about:blank"];
      };
    };

    # Search engines (must be set as a whole dict, not individual keys)
    extraConfig = ''
      c.url.searchengines = {
          "DEFAULT": "https://search.brave.com/search?q={}",
          "b": "https://search.brave.com/search?q={}",
          "nw": "https://nixos.wiki/index.php?search={}",
          "np": "https://search.nixos.org/packages?query={}",
          "no": "https://search.nixos.org/options?query={}",
          "gh": "https://github.com/search?q={}",
          "yt": "https://www.youtube.com/results?search_query={}",
          "w": "https://en.wikipedia.org/w/index.php?search={}",
      }
    '';

    keyBindings = {
      normal = {
        # Quick marks for frequent sites
        "gH" = "open https://github.com";
        "gM" = "open https://mail.proton.me";

        # Tab management (closer to vim)
        "J" = "tab-prev";
        "K" = "tab-next";
        "x" = "tab-close";
        "X" = "undo";

        # Password fill via rofi-rbw
        ",p" = "spawn --detach ${pkgs.rofi-rbw-wayland}/bin/rofi-rbw";
      };
    };
  };
}
