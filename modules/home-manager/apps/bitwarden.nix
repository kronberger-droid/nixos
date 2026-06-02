{pkgs, ...}: {
  home.packages = with pkgs; [
    bitwarden-desktop
    rofi-rbw-wayland
    pinentry-rofi
  ];
  programs.rbw = {
    enable = true;
    settings = {
      email = "kronberger@proton.me";
      pinentry = pkgs.pinentry-rofi;
    };
  };

  # Type via ydotool (kernel /dev/uinput / evdev) instead of the default
  # wtype. wtype uses the Wayland virtual-keyboard protocol and uploads a
  # fresh keymap for every out-of-layout character; Chromium/Firefox drop
  # keys during that swap, so long passwords arrive mangled in browsers
  # while editors work fine. ydotool has no keymap dance and types reliably.
  # Daemon + group membership live in modules/system/desktop/ydotool.nix.
  # start-delay covers focus returning to the browser after rofi closes;
  # key-delay (ms) can be lowered further if typing feels slow.
  xdg.configFile."rofi-rbw.rc".text = ''
    typer = ydotool
    typing-start-delay = 0.4
    typing-key-delay = 8
  '';
}
