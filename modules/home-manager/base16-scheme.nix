{
  config,
  inputs,
  ...
}: {
  # Custom base16 color scheme
  # Base16 format (Standard usage):
  # base00 - Default Background
  # base01 - Lighter Background (Used for status bars, line number and folding marks)
  # base02 - Selection Background
  # base03 - Comments, Invisibles, Line Highlighting
  # base04 - Dark Foreground (Used for status bars)
  # base05 - Default Foreground, Caret, Delimiters, Operators
  # base06 - Light Foreground (Not often used)
  # base07 - Light Background (Not often used)
  # base08 - Error (Variables, XML Tags, Markup Link Text, Markup Lists, Diff Deleted)
  # base09 - Urgent/Warning (Integers, Boolean, Constants, XML Attributes, Markup Link Url)
  # base0A - Warning (Classes, Markup Bold, Search Text Background)
  # base0B - Strings, Inherited Class, Markup Code, Diff Inserted
  # base0C - Support, Regular Expressions, Escape Characters, Markup Quotes
  # base0D - Functions, Methods, Attribute IDs, Headings
  # base0E - Keywords, Storage, Selector, Markup Italic, Diff Changed
  # base0F - Deprecated, Opening/Closing Embedded Language Tags (Custom UI accent)

  scheme = {
    # Dark colors (backgrounds and comments)
    base00 = "1e1e1e"; # Default background (myTheme.backgroundColor / color0)
    base01 = "2c2f33"; # Lighter background (palette.color1)
    base02 = "373c45"; # Selection background (palette.color2)
    base03 = "555555"; # Comments (palette.color3)

    # Light colors (foregrounds)
    base04 = "c0c5ce"; # Dark foreground (palette.color5)
    base05 = "dfe1e8"; # Default foreground (myTheme.textColor / color6)
    base06 = "eff0f1"; # Light foreground (palette.color7)
    base07 = "f5f5f5"; # Light background (not used in original)

    # Accent colors
    base08 = "ac4142"; # Error/Red (from kitty color1)
    base09 = "ac4142"; # Urgent/Red (same as base08 - from kitty color1)
    base0A = "e5b566"; # Warning/Yellow (from kitty color3)
    base0B = "7e8d50"; # Green (from kitty color2)
    base0C = "7dd5cf"; # Cyan (from kitty color6)
    base0D = "6c99ba"; # Blue (from kitty color4)
    base0E = "9e4e85"; # Magenta (from kitty color5)
    base0F = "8a8177"; # Custom accent - brown (myTheme.accentColor / color12)
  };
}
