{ ... }: {
  programs.zathura = {
    enable = true;
    options = {
      recolor = true;
      recolor-darkcolor = "#d0d0d0";
      recolor-lightcolor = "#202020";
      selection-clipboard = "clipboard";
    };
  };
}
