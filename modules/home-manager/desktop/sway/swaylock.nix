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
  # swaylock-effects, and every caller (swayidle timeouts, before-sleep, the
  # rofi powermenu) reads the binary from config.programs.swaylock.package.
  # Before this the settings below were written for pkgs.swaylock while all
  # three callers launched pkgs.swaylock-effects directly, so two lockers sat
  # in the closure and the theming targeted the one nothing ran.
  programs.swaylock = {
    enable = true;
    package = pkgs.swaylock-effects;
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
