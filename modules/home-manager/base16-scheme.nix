{
  config,
  inputs,
  ...
}: {
  # Select a base16 color scheme
  # Available schemes: https://github.com/tinted-theming/schemes/tree/main/base16
  # Popular options:
  # - monokai.yaml - dark, vibrant colors with good contrast
  # - gruvbox-dark-hard.yaml - warm, retro dark theme
  # - nord.yaml - cool, arctic-inspired palette
  # - dracula.yaml - dark purple-ish theme
  # - tomorrow-night.yaml - clean, balanced dark theme
  # - solarized-dark.yaml - classic low-contrast theme

  scheme = "${inputs.tt-schemes}/base16/gruvbox-dark-hard.yaml";
}
