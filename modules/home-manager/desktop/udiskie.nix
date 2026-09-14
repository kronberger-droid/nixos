_: {
  # Auto-mount removable drives with notifications. The service module
  # installs udiskie itself; a second copy in home.packages only ever hid
  # which module owned it.
  services.udiskie = {
    enable = true;
    automount = true;
    notify = true;
    tray = "never"; # No tray icon on Wayland
  };
}
