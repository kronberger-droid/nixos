{pkgs, ...}: {
  home.packages = with pkgs; [
    # Browsers
    brave
    helium

    # Messaging
    thunderbird
    gurk-rs
    element-desktop
    zapzap
    signal-desktop
    fluffychat
    vesktop

    # Documents
    (pkgs.obsidian.overrideAttrs (oldAttrs: {
      postInstall =
        (oldAttrs.postInstall or "")
        + ''
          substituteInPlace $out/share/applications/obsidian.desktop \
            --replace "Exec=obsidian" "Exec=obsidian --enable-features=UseOzonePlatform --ozone-platform=wayland"
        '';
    }))
    onlyoffice-desktopeditors
    zotero
    # Media
    drawio
    inkscape
    gthumb
    (pkgs.gimp-with-plugins.override {
      plugins = [pkgs.gimpPlugins.resynthesizer];
    })
    ffmpeg
    vlc
    obs-studio
    ipe
    gwyddion

    # PDF
    ghostscript
    pdfarranger
    pdfpc

    # Archives
    unrar

    # Security
    openssl

    # Networking
    localsend

    # System
    ltunify
    bluetuith
    wiremix

    # CAD
    freecad-wayland

    # Math
    numbat
  ];
}
