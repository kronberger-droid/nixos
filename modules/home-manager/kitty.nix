{
  pkgs,
  config,
  ...
}: {
  home.packages = with pkgs; [
    imagemagick
  ];

  xdg.configFile."kitty/cwd.sh".source = ./kitty/cwd.sh;

  programs.kitty = {
    enable = true;
    settings = {
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
