{pkgs, ...}: {
  fonts.enableDefaultPackages = false;
  fonts.packages = with pkgs; [
    nerd-fonts.jetbrains-mono
    nerd-fonts._0xproto
    nerd-fonts.symbols-only
    dejavu_fonts
    noto-fonts
    noto-fonts-cjk-sans
    julia-mono # Mono symbol fallback for Rio symbol-map (★ ☀ ✔ ⏺ etc.)

    liberation_ttf
    cm_unicode
    stix-two
    source-serif-pro
  ];
}
