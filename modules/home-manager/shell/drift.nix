{
  config,
  lib,
  pkgs,
  ...
}: let
  s = config.scheme;

  # base16 gives us 16 flat colors, but drift's line washes and intra-line
  # emphasis want an accent tinted *into* the background. Upstream's own hex
  # themes do exactly that (gruvbox: bg #282828 + green #b8bb26 -> add-line
  # #3f4028, add-emph #595a27, i.e. roughly 16% and 34%), and there is no
  # base16 slot that expresses it, so mix the two here.
  #
  # Percentages rather than floats: Nix integer division truncates, which is
  # fine for 8-bit channels and keeps the output stable across evaluations.
  hexDigits = "0123456789abcdef";

  hexToInt = str:
    lib.foldl'
    (acc: c:
      acc
      * 16
      + (lib.strings.charToInt c
        - (
          if c >= "a"
          then 87
          else 48
        )))
    0
    (lib.stringToCharacters (lib.toLower str));

  intToHex = n: let
    clamped =
      if n < 0
      then 0
      else if n > 255
      then 255
      else n;
  in "${builtins.substring (clamped / 16) 1 hexDigits}${builtins.substring (lib.mod clamped 16) 1 hexDigits}";

  # `pct`% of `fg` mixed over `bg`; both are hex strings without a leading '#'.
  mix = pct: fg: bg: let
    channel = offset: let
      a = hexToInt (builtins.substring offset 2 fg);
      b = hexToInt (builtins.substring offset 2 bg);
    in
      intToHex (b + ((a - b) * pct) / 100);
  in "${channel 0}${channel 2}${channel 4}";

  # Dialled well below upstream's ~16%: their themes assume additions are
  # interspersed with context, but on a mostly-added diff the wash covers the
  # whole screen and stops being a highlight, becoming a lifted background
  # that costs contrast on every syntax color at once.
  wash = c: mix 6 c s.base00; # whole-line background
  emph = c: mix 30 c s.base00; # intra-line changed-word background

  # Scopes and their order mirror `builtin_theme` in drift's highlight.rs, so
  # highlighting covers exactly what the built-in palettes cover; only the
  # hues differ. Slot choices are base16's own documented semantics, the same
  # ones base16_transparent gives Helix, so code is colored identically in the
  # editor and the pager.
  syntaxScopes = [
    {
      scope = "comment";
      color = s.base03;
      italic = true;
    }
    {
      scope = "string";
      color = s.base0B;
    }
    # base09 is the constants slot. Note this scheme sets base09 = base08 on
    # purpose ("keeps the bright-red slot red, not orange"), so numbers and
    # variables share a hue here. That is the scheme's call, not a mapping bug.
    {
      scope = "constant.numeric";
      color = s.base09;
    }
    {
      scope = "constant.language, constant.character, constant.other";
      color = s.base09;
    }
    {
      scope = "support.constant";
      color = s.base0C;
    }
    {
      scope = "keyword, storage, keyword.control";
      color = s.base0E;
    }
    {
      scope = "keyword.operator";
      color = s.base0C;
    }
    {
      scope = "entity.name.function, support.function, meta.function-call";
      color = s.base0D;
    }
    {
      scope = "entity.name.type, entity.name.class, support.type, support.class, storage.type";
      color = s.base0A;
    }
    {
      scope = "variable.parameter";
      color = s.base08;
    }
    {
      scope = "entity.name.tag";
      color = s.base08;
    }
    {
      scope = "entity.other.attribute-name";
      color = s.base09;
    }
  ];

  scopeEntry = e: ''
    <dict>
      <key>scope</key><string>${e.scope}</string>
      <key>settings</key>
      <dict>
        <key>foreground</key><string>#${e.color}</string>${
      lib.optionalString (e.italic or false) ''

        <key>fontStyle</key><string>italic</string>''
    }
      </dict>
    </dict>'';

  tmTheme = pkgs.writeText "base16-scheme.tmTheme" ''
    <?xml version="1.0" encoding="UTF-8"?>
    <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
    <plist version="1.0">
    <dict>
      <key>name</key><string>base16-scheme</string>
      <key>settings</key>
      <array>
        <dict>
          <key>settings</key>
          <dict>
            <key>background</key><string>#${s.base00}</string>
            <key>foreground</key><string>#${s.base05}</string>
          </dict>
        </dict>
    ${lib.concatMapStringsSep "\n" scopeEntry syntaxScopes}
      </array>
    </dict>
    </plist>
  '';
in {
  home.packages = [(pkgs.callPackage ../../shared/drift.nix {})];

  # `theme` does two independent jobs, and pointing it at the generated
  # tmTheme (via the patch in modules/shared/drift.nix) satisfies both:
  #
  #   - UI chrome: the path is not a known built-in, so drift falls back to
  #     the ansi palette for defaults — every [colors] key below then
  #     overrides it outright, so none of that fallback survives.
  #   - Syntax hues: the patched loader reads the file, giving us this scheme
  #     rather than one of the bundled palettes.
  #
  # Highlighting is gated on a single string compare, `syntax && theme !=
  # "ansi"` (config.rs), so a path also keeps it switched on. The bundled
  # alternative, base16-ocean.dark, measured 0.29 mean saturation against
  # this scheme's 0.50 and read visibly washed out on a real diff.
  xdg.configFile."drift/config.toml".text = ''
    theme = "${tmTheme}"
    syntax = true
    intraline = true
    line-numbers = true
    tab-width = 4

    [colors]
    add         = "#${s.base0B}"
    remove      = "#${s.base08}"
    context     = "#${s.base05}"
    header      = "#${s.base0D}"
    line-number = "#${s.base03}"
    # base0F is the UI accent everywhere else (rofi `selected`, waybar), so the
    # logo badge picks it up too; secondary stays blue like the rest of the
    # chrome. `background` is not the app background, it is the text drawn on
    # top of those accent badges, hence base00.
    primary     = "#${s.base0F}"
    secondary   = "#${s.base0D}"
    foreground  = "#${s.base05}"
    background  = "#${s.base00}"
    # base04, not base03: `muted` carries statusbar flags and help text over
    # the base01 surface, and upstream already special-cases the ansi theme for
    # having a too-dim muted there. base16 spec'd base04 for status bars.
    muted       = "#${s.base04}"
    surface     = "#${s.base01}"
    cursor      = "#${s.base02}"
    add-line    = "#${wash s.base0B}"
    remove-line = "#${wash s.base08}"
    header-line = "#${wash s.base0D}"
    add-emph    = "#${emph s.base0B}"
    remove-emph = "#${emph s.base08}"
  '';
}
