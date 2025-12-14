{
  pkgs,
  config,
  ...
}: let
  c = config.scheme;
in {
  programs.qutebrowser = {
    enable = true;

    settings = {
      # Tab position
      tabs.position = "right";
      tabs.show = "multiple";

      # Colors - Completion widget
      colors.completion.category.bg = "#${c.base00}";
      colors.completion.category.border.bottom = "#${c.base00}";
      colors.completion.category.border.top = "#${c.base00}";
      colors.completion.category.fg = "#${c.base0D}";
      colors.completion.even.bg = "#${c.base00}";
      colors.completion.odd.bg = "#${c.base00}";
      colors.completion.fg = "#${c.base05}";
      colors.completion.item.selected.bg = "#${c.base02}";
      colors.completion.item.selected.border.bottom = "#${c.base02}";
      colors.completion.item.selected.border.top = "#${c.base02}";
      colors.completion.item.selected.fg = "#${c.base05}";
      colors.completion.match.fg = "#${c.base0B}";
      colors.completion.scrollbar.bg = "#${c.base00}";
      colors.completion.scrollbar.fg = "#${c.base05}";

      # Colors - Context menu
      colors.contextmenu.menu.bg = "#${c.base00}";
      colors.contextmenu.menu.fg = "#${c.base05}";
      colors.contextmenu.selected.bg = "#${c.base02}";
      colors.contextmenu.selected.fg = "#${c.base05}";

      # Colors - Downloads
      colors.downloads.bar.bg = "#${c.base00}";
      colors.downloads.error.bg = "#${c.base08}";
      colors.downloads.error.fg = "#${c.base00}";
      colors.downloads.start.bg = "#${c.base0D}";
      colors.downloads.start.fg = "#${c.base00}";
      colors.downloads.stop.bg = "#${c.base0B}";
      colors.downloads.stop.fg = "#${c.base00}";

      # Colors - Hints
      colors.hints.bg = "#${c.base0A}";
      colors.hints.fg = "#${c.base00}";
      colors.hints.match.fg = "#${c.base05}";

      # Colors - Keyhint widget
      colors.keyhint.bg = "#${c.base00}";
      colors.keyhint.fg = "#${c.base05}";
      colors.keyhint.suffix.fg = "#${c.base0B}";

      # Colors - Messages
      colors.messages.error.bg = "#${c.base08}";
      colors.messages.error.border = "#${c.base08}";
      colors.messages.error.fg = "#${c.base00}";
      colors.messages.info.bg = "#${c.base00}";
      colors.messages.info.border = "#${c.base00}";
      colors.messages.info.fg = "#${c.base05}";
      colors.messages.warning.bg = "#${c.base0A}";
      colors.messages.warning.border = "#${c.base0A}";
      colors.messages.warning.fg = "#${c.base00}";

      # Colors - Prompts
      colors.prompts.bg = "#${c.base00}";
      colors.prompts.border = "#${c.base00}";
      colors.prompts.fg = "#${c.base05}";
      colors.prompts.selected.bg = "#${c.base02}";
      colors.prompts.selected.fg = "#${c.base05}";

      # Colors - Statusbar
      colors.statusbar.caret.bg = "#${c.base00}";
      colors.statusbar.caret.fg = "#${c.base0D}";
      colors.statusbar.caret.selection.bg = "#${c.base00}";
      colors.statusbar.caret.selection.fg = "#${c.base0D}";
      colors.statusbar.command.bg = "#${c.base00}";
      colors.statusbar.command.fg = "#${c.base05}";
      colors.statusbar.command.private.bg = "#${c.base00}";
      colors.statusbar.command.private.fg = "#${c.base05}";
      colors.statusbar.insert.bg = "#${c.base00}";
      colors.statusbar.insert.fg = "#${c.base0B}";
      colors.statusbar.normal.bg = "#${c.base00}";
      colors.statusbar.normal.fg = "#${c.base05}";
      colors.statusbar.passthrough.bg = "#${c.base00}";
      colors.statusbar.passthrough.fg = "#${c.base0D}";
      colors.statusbar.private.bg = "#${c.base00}";
      colors.statusbar.private.fg = "#${c.base05}";
      colors.statusbar.progress.bg = "#${c.base0D}";
      colors.statusbar.url.error.fg = "#${c.base08}";
      colors.statusbar.url.fg = "#${c.base05}";
      colors.statusbar.url.hover.fg = "#${c.base0C}";
      colors.statusbar.url.success.http.fg = "#${c.base0B}";
      colors.statusbar.url.success.https.fg = "#${c.base0B}";
      colors.statusbar.url.warn.fg = "#${c.base0A}";

      # Colors - Tabs
      colors.tabs.bar.bg = "#${c.base00}";
      colors.tabs.even.bg = "#${c.base00}";
      colors.tabs.even.fg = "#${c.base04}";
      colors.tabs.odd.bg = "#${c.base00}";
      colors.tabs.odd.fg = "#${c.base04}";
      colors.tabs.selected.even.bg = "#${c.base01}";
      colors.tabs.selected.even.fg = "#${c.base05}";
      colors.tabs.selected.odd.bg = "#${c.base01}";
      colors.tabs.selected.odd.fg = "#${c.base05}";
      colors.tabs.indicator.error = "#${c.base08}";
      colors.tabs.indicator.start = "#${c.base0D}";
      colors.tabs.indicator.stop = "#${c.base0B}";

      # Colors - Webpage
      colors.webpage.bg = "#${c.base00}";
      colors.webpage.preferred_color_scheme = "dark";

      # Fonts
      fonts.default_family = "monospace";
      fonts.default_size = "10pt";

      # Content settings
      content.autoplay = false;
      content.notifications.enabled = false;

      # Homepage
      url.default_page = "about:blank";
      url.start_pages = "about:blank";

      # Privacy
      content.cookies.accept = "no-3rdparty";
      content.headers.do_not_track = true;
    };

    keyBindings = {
      normal = {
        ",m" = "hint links spawn mpv {hint-url}";
        ",M" = "spawn mpv {url}";
      };
    };
  };
}
