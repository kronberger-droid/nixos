{
  config,
  pkgs,
  host,
  ...
}: let
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
      inside-color = "#${config.scheme.base00}CC";
      indicator-radius = builtins.ceil (80 * scale);
      ring-color = "#${config.scheme.base00}";
      key-hl-color = "#${config.scheme.base0F}";
      show-failed-attempts = true;
      ignore-empty-password = true;
    };
  };
}
