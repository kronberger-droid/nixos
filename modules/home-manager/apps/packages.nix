{pkgs, ...}: {
  home.packages = with pkgs; [
    # Browsers
    helium
    ladybird

    # Messaging
    aerion
    zapzap
    # signal-desktop: sandboxed, see signal.nix
    # equibop: sandboxed, see equibop.nix. It replaces vesktop, which could
    # not render incoming webcams on P14E. Same venmic screenshare lineage
    # (Equibop forks vesktop) on a newer Electron, and it builds with bun
    # rather than the CVE-flagged pnpm.

    # Documents
    obsidian
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
    # The eww clock's dropdown TUI. Listed here as well as in the script's
    # store-path reference so it is reachable from a plain shell.
    calcurse

    # Math
    numbat
  ];
}
