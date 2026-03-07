{pkgs, ...}: {
  home.packages = with pkgs; [
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
  ];
}
