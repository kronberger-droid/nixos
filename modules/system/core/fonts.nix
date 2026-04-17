{pkgs, ...}: {
  fonts.enableDefaultPackages = false;
  fonts.packages = with pkgs; [
    nerd-fonts.jetbrains-mono
    nerd-fonts.symbols-only
    dejavu_fonts
    noto-fonts
    noto-fonts-cjk-sans

    liberation_ttf
    cm_unicode
    stix-two
    source-serif-pro
  ];
}
