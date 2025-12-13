{ config, ... }: {
  programs.zathura = {
    enable = true;
    options = {
      recolor = true;
      recolor-darkcolor = "#${config.scheme.base05}"; # Use base05 for text
      recolor-lightcolor = "#${config.scheme.base00}"; # Use base00 for background
      selection-clipboard = "clipboard";
      # Additional base16 colors
      default-bg = "#${config.scheme.base00}";
      default-fg = "#${config.scheme.base05}";
      statusbar-bg = "#${config.scheme.base01}";
      statusbar-fg = "#${config.scheme.base05}";
      inputbar-bg = "#${config.scheme.base00}";
      inputbar-fg = "#${config.scheme.base05}";
      notification-bg = "#${config.scheme.base00}";
      notification-fg = "#${config.scheme.base05}";
      notification-error-bg = "#${config.scheme.base08}";
      notification-error-fg = "#${config.scheme.base00}";
      notification-warning-bg = "#${config.scheme.base0A}";
      notification-warning-fg = "#${config.scheme.base00}";
      highlight-color = "#${config.scheme.base0A}";
      highlight-active-color = "#${config.scheme.base0D}";
      completion-bg = "#${config.scheme.base01}";
      completion-fg = "#${config.scheme.base05}";
      completion-highlight-bg = "#${config.scheme.base0F}";
      completion-highlight-fg = "#${config.scheme.base05}";
    };
  };
}
