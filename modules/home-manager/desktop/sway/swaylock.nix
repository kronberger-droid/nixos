{
  config,
  pkgs,
  host,
  ...
}: let
  inherit (config.myTheme) backgroundColor accentColor;
  scale =
    if host == "spectre"
    then 1.25
    else 1.0;
in {
  home.packages = with pkgs; [
    swaylock
  ];

  programs.swaylock = {
    enable = true;
    package = pkgs.swaylock;
    settings = {
      image = "${./deathpaper.jpg}";
      font-size = builtins.ceil (24 * scale);
      indicator-idle-visible = false;
      inside-color = backgroundColor + "CC";
      indicator-radius = builtins.ceil (80 * scale);
      ring-color = backgroundColor;
      key-hl-color = accentColor;
      show-failed-attempts = true;
      ignore-empty-password = true;
    };
  };
}
