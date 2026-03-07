{...}: {
  fonts.fontconfig.enable = true;

  home.file = {
    ".local/share/fonts/Futura_PT".source = ./fonts/Futura_PT;
    ".local/share/fonts/gfsneohellenicmath".source = ./fonts/gfsneohellenicmath;
  };
}
