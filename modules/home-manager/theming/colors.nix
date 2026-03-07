{lib, ...}: let
  mk = lib.mkOption;
  inherit (lib) types;
in {
  options.myTheme = {
    palette = mk {
      type = types.attrsOf types.str;
      default = {
        color0 = "#1e1e1e";
        color1 = "#2c2f33";
        color2 = "#373c45";
        color3 = "#555555";
        color4 = "#6c7a89";
        color5 = "#c0c5ce";
        color6 = "#dfe1e8";
        color7 = "#eff0f1";
        color8 = "#423c38";
        color9 = "#6e665f";
        color10 = "#786048";
        color11 = "#988a71";
        color12 = "#8a8177";
        color13 = "#9c9287";
        color14 = "#a39e93";
        color15 = "#b6b1a9";
      };
      description = "Your full 16-color palette";
    };

    backgroundColor = mk {
      type = types.str;
      default = "#1e1e1e"; # corresponds to palette.color0
      description = "Base background colour";
    };

    accentColor = mk {
      type = types.str;
      default = "#8a8177"; # corresponds to palette.color12
      description = "Accent/highlight colour";
    };

    textColor = mk {
      type = types.str;
      default = "#dfe1e8"; # corresponds to palette.color6
      description = "Main text colour";
    };
  };
}
