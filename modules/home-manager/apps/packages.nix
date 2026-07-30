{pkgs, ...}: {
  home.packages = with pkgs; [
    # Browsers
    brave
    helium

    # Messaging
    thunderbird
    aerion
    # gurk-rs
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
    # 2.70 (GTK2) kept as the fallback — it goes through XWayland and renders
    # at half size on scaled outputs. `gwyddion3` is the GTK3/Wayland-native
    # build and is the one to reach for; see modules/shared/gwyddion3.nix.
    gwyddion
    (pkgs.callPackage ../../shared/gwyddion3.nix {})

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
    sshfs # mount remote SFTP/SSH dirs locally (see sftp-mount in nushell)

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
