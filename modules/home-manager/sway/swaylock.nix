{ config, lib, pkgs, colors, ... }:
{
  home.packages = [
    pkgs.sway-audio-idle-inhibit
  ];

  programs.swaylock = {
    enable = true;
    package = pkgs.swaylock;
    settings = {
      image = "${./sway/deathpaper.jpg}";
      font-size = 24;
      indicator-idle-visible = false;
      inside-color = colors.backgroundColor + "CC";
      indicator-radius = 80;
      ring-color = colors.backgroundColor;
      key-hl-color = colors.accentColor;
      show-failed-attempts = true;
      ignore-empty-password = true;
    };
  };
}
