{ config, lib, pkgs, ... }:{
  programs.zathura = {
    enable = true;
    options = {
      recolor = true;
      recolor-darkcolor = "#d0d0d0";  # Matches kitty's foreground (text color)
      recolor-lightcolor = "#202020";  # Matches kitty's background (dark mode)
    };
  };
}
