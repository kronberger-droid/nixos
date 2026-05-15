{...}: {
  imports = [
    ./compositor.nix
    ./niri.nix
    ./sway.nix
    ./waybar.nix
    # ./ironbar.nix
    ./rofi.nix
    ./kanshi.nix
    ./session-services.nix
    ./udiskie.nix
    ./xdg.nix
  ];
}
