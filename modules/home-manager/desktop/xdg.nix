_: {
  xdg = {
    enable = true;
    userDirs = {
      enable = true;
      createDirectories = true;
      setSessionVariables = true;
      documents = "$HOME/Documents";
      download = "$HOME/Downloads";
      music = "$HOME/Music";
      pictures = "$HOME/Pictures";
      videos = "$HOME/Videos";
      desktop = "$HOME/Desktop";
      publicShare = "$HOME/Public";
      templates = "$HOME/Templates";
    };
    mimeApps = {
      enable = true;
      defaultApplications = {
        "application/pdf" = "org.pwmt.zathura.desktop";
        # aerion rather than aerc: both are in use, but aerc's desktop entry
        # is `Terminal=true`, so handing it a mailto: link means spawning a
        # terminal for it.
        "x-scheme-handler/mailto" = "io.github.hkdb.Aerion.desktop";
        "x-scheme-handler/http" = "helium.desktop";
        "x-scheme-handler/https" = "helium.desktop";
        "text/html" = "helium.desktop";
        "application/xhtml+xml" = "helium.desktop";
        "image/png" = "swayimg.desktop";
        "image/jpeg" = "swayimg.desktop";
        "image/gif" = "swayimg.desktop";
        "image/webp" = "swayimg.desktop";
        "image/svg+xml" = "swayimg.desktop";
        "image/tiff" = "swayimg.desktop";
      };
    };
  };
}
