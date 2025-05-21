{ config, lib, pkgs, ... }:{
  programs.zathura = {
    enable = true;
    options = {
      recolor = false;
      recolor-darkcolor = "#d0d0d0";
      recolor-lightcolor = "#202020";
      selection-clipboard = "clipboard";
    };
  };
}
