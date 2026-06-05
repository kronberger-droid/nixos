{
  config,
  lib,
  ...
}: let
  s = config.scheme;
in {
  # Single source of truth for the 16-slot ANSI terminal palette, derived
  # from the base16 `scheme`. Consumed by the kitty + rio ANSI colors and by
  # Helix's generated palette, so the base16→ANSI mapping policy (which base0X
  # fills which slot, including the orange base09 in slot 9) lives in exactly
  # one place instead of being hand-copied across three files.
  #
  # Values are hex WITHOUT a leading '#', matching how `scheme.base0X` is used
  # elsewhere — each consumer prefixes '#'. Note the base16 convention that the
  # "bright" green/yellow/blue/magenta/cyan reuse the same accents as their
  # normal variants (base16 has only 8 hues); only bright-black (base03),
  # bright-red (base09) and bright-white (base07) differ.
  options.ansi = lib.mkOption {
    type = lib.types.attrsOf lib.types.str;
    internal = true;
    description = "base16→ANSI 16-color mapping (hex, no leading '#').";
  };

  config.ansi = {
    black = s.base00; # 0
    red = s.base08; # 1
    green = s.base0B; # 2
    yellow = s.base0A; # 3
    blue = s.base0D; # 4
    magenta = s.base0E; # 5
    cyan = s.base0C; # 6
    white = s.base05; # 7
    bright-black = s.base03; # 8
    bright-red = s.base09; # 9  (orange in base16)
    bright-green = s.base0B; # 10
    bright-yellow = s.base0A; # 11
    bright-blue = s.base0D; # 12
    bright-magenta = s.base0E; # 13
    bright-cyan = s.base0C; # 14
    bright-white = s.base07; # 15
  };
}
