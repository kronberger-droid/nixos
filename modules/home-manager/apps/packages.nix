{pkgs, ...}: {
  home.packages = with pkgs; [
    # Browsers
    tor-browser
    librewolf
    brave

    # Messaging
    thunderbird
    gurk-rs
    element-desktop
    zapzap
    signal-desktop
    fluffychat

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
    zotero-beta
    neovim

    # Media
    drawio
    inkscape
    gthumb
    (pkgs.gimp-with-plugins.override {
      plugins = [pkgs.gimpPlugins.resynthesizer];
    })
    ffmpeg_6
    vlc
    obs-studio
    ipe
    fiji

    # PDF
    ghostscript
    pdfarranger
    pdfpc
    inlyne
    zathura

    # Security
    seahorse
    bitwarden-desktop
    rofi-rbw-wayland
    rbw
    openssl
    libsecret

    # Networking
    localsend

    # System
    ltunify
    bluetuith
    wiremix

    # Wine
    wine
    winetricks

    # CAD
    freecad-wayland

    # Math
    numbat
  ];
}
