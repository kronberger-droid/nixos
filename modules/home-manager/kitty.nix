{ config, pkgs, lib, ... }:

{
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

      # Theme
      background_opacity = 1.0;
      background = "#202020";
      foreground = "#d0d0d0";
      cursor = "#d0d0d0";
      selection_background = "#eecb8b";
      color0 = "#151515";
      color8 = "#505050";
      color1 = "#ac4142";
      color9 = "#ac4142";
      color2 = "#7e8d50";
      color10 = "#7e8d50";
      color3 = "#e5b566";
      color11 = "#e5b566";
      color4 = "#6c99ba";
      color12 = "#6c99ba";
      color5 = "#9e4e85";
      color13 = "#9e4e85";
      color6 = "#7dd5cf";
      color14 = "#7dd5cf";
      color7 = "#d0d0d0";
      color15 = "#f5f5f5";
      selection_foreground = "#232323";
    };
  };
}
