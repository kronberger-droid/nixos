# The icon theme, a function of pkgs like gtk-theme.nix. Adwaita, with the
# emblems (the symlink arrow, the read-only lock) replaced.
#
# GTK draws an emblem at half the size of the icon it sits on, whatever the
# theme. Adwaita ships its emblems as 16px PNGs whose badge fills the whole
# canvas, so in Nemo they came out blurred and covering a quarter of each
# folder. Qogir's are SVGs with the badge on about two thirds of the canvas,
# which is the size the half-icon slot was meant to hold.
pkgs: rec {
  name = "Adwaita-emblems";
  package = pkgs.runCommandLocal "adwaita-emblems-icon-theme" {} ''
    theme=$out/share/icons/${name}
    mkdir -p $theme
    cp -rL ${pkgs.qogir-icon-theme}/share/icons/Qogir/22/emblems $theme/emblems
    cat > $theme/index.theme <<INDEX
    [Icon Theme]
    Name=${name}
    Comment=Adwaita with Qogir's emblems
    Inherits=Adwaita,hicolor
    Directories=emblems

    [emblems]
    Context=Emblems
    Size=22
    MinSize=8
    MaxSize=512
    Type=Scalable
    INDEX
  '';
}
