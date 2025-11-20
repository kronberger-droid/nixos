{ pkgs, ... }:

{
  # Auto-mount removable drives with notifications
  services.udiskie = {
    enable = true;
    automount = true;
    notify = true;
    tray = "never"; # No tray icon on Wayland
  };

  home.packages = with pkgs; [
    udiskie
  ];
}
