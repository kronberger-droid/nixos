{ config, lib, pkgs, backgroundColor, accentColor, ... }:
{
  home.packages = [
    pkgs.swaylock
  ];

  programs.swaylock = {
    enable = true;
    package = pkgs.swaylock;
    settings = {
      image = "${./deathpaper.jpg}";
      font-size = 24;
      indicator-idle-visible = false;
      inside-color = backgroundColor + "CC";
      indicator-radius = 80;
      ring-color = backgroundColor;
      key-hl-color = accentColor;
      show-failed-attempts = true;
      ignore-empty-password = true;
    };
  };
}
