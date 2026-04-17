_: {
  fonts.fontconfig.enable = true;

  # Prefer monochrome symbol fonts over Noto Color Emoji
  xdg.configFile."fontconfig/conf.d/90-monochrome-emoji.conf".text = ''
    <?xml version="1.0"?>
    <!DOCTYPE fontconfig SYSTEM "urn:fontconfig:fonts.dtd">
    <fontconfig>
      <!-- Deprioritize color emoji in favor of monochrome symbol fonts -->
      <alias binding="strong">
        <family>emoji</family>
        <prefer>
          <family>Noto Sans Symbols 2</family>
          <family>STIX Two Math</family>
          <family>DejaVu Sans</family>
        </prefer>
      </alias>
      <!-- Ensure Noto Color Emoji is last resort -->
      <alias binding="strong">
        <family>Noto Color Emoji</family>
        <prefer>
          <family>Noto Sans Symbols 2</family>
          <family>STIX Two Math</family>
          <family>DejaVu Sans</family>
        </prefer>
      </alias>
    </fontconfig>
  '';

  home.file = {
    ".local/share/fonts/Futura_PT".source = ./fonts/Futura_PT;
    ".local/share/fonts/gfsneohellenicmath".source = ./fonts/gfsneohellenicmath;
  };
}
