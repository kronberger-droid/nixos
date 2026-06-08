{pkgs, ...}: {
  fonts.enableDefaultPackages = false;
  fonts.packages = with pkgs; [
    nerd-fonts.jetbrains-mono
    nerd-fonts._0xproto
    nerd-fonts.symbols-only
    dejavu_fonts
    inter # modern sans-serif — recommended Standard/Sans-serif font for the browser
    (google-fonts.override {fonts = ["ChakraPetch"];}) # Chakra Petch — geometric/techy display sans
    noto-fonts
    noto-fonts-cjk-sans
    julia-mono # Mono symbol fallback for Rio symbol-map (★ ☀ ✔ ⏺ etc.)
    symbola # Monochrome coverage for SMP emoji (🚀 ✅ 🟢 …) that Noto Sans Symbols 2 lacks
    noto-fonts-monochrome-emoji # Grayscale emoji (family "Noto Emoji") for Rio's symbol-map; subtle monochrome sibling of Noto Color Emoji, far broader coverage than Symbola

    liberation_ttf
    cm_unicode
    stix-two
    source-serif-pro
  ];
}
