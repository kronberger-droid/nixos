{
  pkgs,
  config,
  ...
}: {
  home.packages = with pkgs; [
    imagemagick
  ];

  xdg.configFile."kitty/cwd.sh" = {
    executable = true;
    text = ''
      #!${pkgs.bash}/bin/bash
      # Print working directory of the focused window, or $HOME.
      # Only uses cwd for terminals and file managers, not browsers/other apps.
      # Supports both sway and niri.

      if [ -n "$NIRI_SOCKET" ] && [ -S "$NIRI_SOCKET" ]; then
          focused=$(${pkgs.niri}/bin/niri msg -j focused-window)
          app_id=$(echo "$focused" | ${pkgs.jq}/bin/jq -r '.app_id // empty')
          pid=$(echo "$focused" | ${pkgs.jq}/bin/jq -r '.pid')
      elif [ -n "$SWAYSOCK" ] && [ -S "$SWAYSOCK" ]; then
          focused=$(${pkgs.sway}/bin/swaymsg -t get_tree | ${pkgs.jq}/bin/jq -r \
                '.. | select(.type?) | select(.type=="con") | select(.focused==true)')
          app_id=$(echo "$focused" | ${pkgs.jq}/bin/jq -r '.app_id // empty')
          pid=$(echo "$focused" | ${pkgs.jq}/bin/jq -r '.pid')
      else
          echo "$HOME"
          exit 0
      fi

      relevant_apps="kitty|rio|foot|alacritty|wezterm|ghostty|nemo|nautilus|thunar|yazi|ranger|helix|nvim|vim|emacs|code|zed"

      if [[ "$app_id" =~ ^($relevant_apps) ]]; then
          ppid=$(${pkgs.procps}/bin/pgrep --newest --parent "$pid")
          cwd=$(${pkgs.coreutils}/bin/readlink "/proc/''${ppid}/cwd" 2>/dev/null || true)
          echo "''${cwd:-$HOME}"
      else
          echo "$HOME"
      fi
    '';
  };

  programs.kitty = {
    enable = true;
    keybindings = {
      "ctrl+shift+o" = "show_scrollback";
      # Copy last command output to clipboard
      "ctrl+shift+y" = "launch --stdin-source=@last_cmd_output --type=background wl-copy";
      # Copy entire scrollback to clipboard
      "ctrl+shift+u" = "launch --stdin-source=@screen_scrollback --type=background wl-copy";
    };
    settings = {
      # scrollback_pager = "hx";
      # No confirmation
      confirm_os_window_close = 0;

      # Fonts — kept visually in sync with rio.nix. NOTE the unit difference:
      # rio's `size` is in PIXELS (16px), kitty's `font_size` is in POINTS.
      # Strict 96-DPI conversion: pt = px * 72/96 = 16 * 0.75 = 12pt. Both
      # terminals are fractional-scaling aware and apply the output scale
      # identically, so it cancels and only this unit conversion matters.
      # Weights mirror rio: regular = Medium (500), bold = Bold (700), italics
      # match. The "NL" family is the no-ligatures variant — nothing to disable.
      font_size = "12.0";
      font_family = ''family="JetBrainsMonoNL Nerd Font" style="Medium"'';
      bold_font = ''family="JetBrainsMonoNL Nerd Font" style="Bold"'';
      italic_font = ''family="JetBrainsMonoNL Nerd Font" style="Medium Italic"'';
      bold_italic_font = ''family="JetBrainsMonoNL Nerd Font" style="Bold Italic"'';

      # for dropdown menu
      allow_remote_control = "socket-only";
      listen_on = "unix:/tmp/kitty-rc.sock";

      # Theme - using base16 scheme
      background_opacity = "1.0";
      background = "#${config.scheme.base00}";
      foreground = "#${config.scheme.base05}";
      cursor = "#${config.scheme.base05}";
      selection_background = "#${config.scheme.base02}";
      selection_foreground = "#${config.scheme.base05}";

      # ANSI colors (sourced from config.ansi — shared with rio + helix)
      color0 = "#${config.ansi.black}";
      color1 = "#${config.ansi.red}";
      color2 = "#${config.ansi.green}";
      color3 = "#${config.ansi.yellow}";
      color4 = "#${config.ansi.blue}";
      color5 = "#${config.ansi.magenta}";
      color6 = "#${config.ansi.cyan}";
      color7 = "#${config.ansi.white}";

      # Bright ANSI colors
      color8 = "#${config.ansi."bright-black"}";
      color9 = "#${config.ansi."bright-red"}";
      color10 = "#${config.ansi."bright-green"}";
      color11 = "#${config.ansi."bright-yellow"}";
      color12 = "#${config.ansi."bright-blue"}";
      color13 = "#${config.ansi."bright-magenta"}";
      color14 = "#${config.ansi."bright-cyan"}";
      color15 = "#${config.ansi."bright-white"}";
    };
  };
}
