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

      # ANSI colors
      color0 = "#${config.scheme.base00}"; # black
      color1 = "#${config.scheme.base08}"; # red
      color2 = "#${config.scheme.base0B}"; # green
      color3 = "#${config.scheme.base0A}"; # yellow
      color4 = "#${config.scheme.base0D}"; # blue
      color5 = "#${config.scheme.base0E}"; # magenta
      color6 = "#${config.scheme.base0C}"; # cyan
      color7 = "#${config.scheme.base05}"; # white

      # Bright ANSI colors
      color8 = "#${config.scheme.base03}"; # bright black (gray)
      color9 = "#${config.scheme.base09}"; # bright red
      color10 = "#${config.scheme.base0B}"; # bright green
      color11 = "#${config.scheme.base0A}"; # bright yellow
      color12 = "#${config.scheme.base0D}"; # bright blue
      color13 = "#${config.scheme.base0E}"; # bright magenta
      color14 = "#${config.scheme.base0C}"; # bright cyan
      color15 = "#${config.scheme.base07}"; # bright white
    };
  };
}
