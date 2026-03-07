{pkgs, ...}: {
  home.packages = with pkgs; [
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
  ];
}
