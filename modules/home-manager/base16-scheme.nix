{
  config,
  inputs,
  ...
}: {
  # Custom base16 color scheme
  # Base16 format:
  # base00 - Default Background
  # base01 - Lighter Background (Used for status bars, line number and folding marks)
  # base02 - Selection Background
  # base03 - Comments, Invisibles, Line Highlighting
  # base04 - Dark Foreground (Used for status bars)
  # base05 - Default Foreground, Caret, Delimiters, Operators
  # base06 - Light Foreground (Not often used)
  # base07 - Light Background (Not often used)
  # base08 - Variables, XML Tags, Markup Link Text, Markup Lists, Diff Deleted
  # base09 - Integers, Boolean, Constants, XML Attributes, Markup Link Url
  # base0A - Classes, Markup Bold, Search Text Background
  # base0B - Strings, Inherited Class, Markup Code, Diff Inserted
  # base0C - Support, Regular Expressions, Escape Characters, Markup Quotes
  # base0D - Functions, Methods, Attribute IDs, Headings
  # base0E - Keywords, Storage, Selector, Markup Italic, Diff Changed
  # base0F - Deprecated, Opening/Closing Embedded Language Tags

  scheme = {
    base00 = "202020"; # Background (from kitty background)
    base01 = "151515"; # Lighter Background (from kitty color0/black)
    base02 = "505050"; # Selection Background (from kitty color8/bright black)
    base03 = "505050"; # Comments (from kitty color8/bright black)
    base04 = "d0d0d0"; # Dark Foreground (from kitty foreground/color7)
    base05 = "d0d0d0"; # Default Foreground (from kitty foreground/color7)
    base06 = "f5f5f5"; # Light Foreground (from kitty color15/bright white)
    base07 = "f5f5f5"; # Light Background (from kitty color15/bright white)
    base08 = "ac4142"; # Red (from kitty color1/red)
    base09 = "ac4142"; # Orange (using red from kitty color9/bright red)
    base0A = "e5b566"; # Yellow (from kitty color3/yellow)
    base0B = "7e8d50"; # Green (from kitty color2/green)
    base0C = "7dd5cf"; # Cyan (from kitty color6/cyan)
    base0D = "6c99ba"; # Blue (from kitty color4/blue)
    base0E = "9e4e85"; # Magenta (from kitty color5/magenta)
    base0F = "ac4142"; # Brown (using red as fallback)
  };
}
