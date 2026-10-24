{pkgs, ...}: {
  home.packages = with pkgs; [
    # Browsers
    helium
    ladybird

    # Messaging
    # aerion, zapzap: sandboxed, see aerion.nix and zapzap.nix
    # signal-desktop: sandboxed, see signal.nix
    # equibop: sandboxed, see equibop.nix. It replaces vesktop, which could
    # not render incoming webcams on P14E. Same venmic screenshare lineage
    # (Equibop forks vesktop) on a newer Electron, and it builds with bun
    # rather than the CVE-flagged pnpm.

    # Documents
    obsidian
    # onlyoffice-desktopeditors: from Flathub, see flatpak.nix
    zotero

    # Media
    drawio
    inkscape
    # Photo browsing. Not the image/* default: that stays swayimg (xdg.nix),
    # which is also yazi's opener.
    loupe
    (pkgs.gimp-with-plugins.override {
      plugins = [pkgs.gimpPlugins.resynthesizer];
    })
    ffmpeg
    vlc
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
    # localsend: sandboxed, see localsend.nix
    sshfs # mount remote SFTP/SSH dirs locally (see sftp-mount in nushell)

    # System
    ltunify
    bluetui
    wiremix
    # The bar clock's dropdown TUI. Listed here as well as in the script's
    # store-path reference so it is reachable from a plain shell.
    calcurse

    # Math
    numbat
  ];
}
