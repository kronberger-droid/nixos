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
      base_url = "https://vault.bitwarden.eu";
      pinentry = pkgs.pinentry-rofi;
    };
  };

  # Default action is autotype (Enter types username+Tab+password) via wtype,
  # which works in editors and Firefox. wtype needs no daemon, group, or keyd
  # handling (unlike ydotool), so we use it and keep no extra machinery.
  #
  # Caveat: Chromium-based browsers (Helium, Brave) drop/stutter synthetic
  # keystrokes from any typer — an upstream Chromium/Wayland input limitation,
  # cf. https://github.com/atx/wtype/issues/31. For those, use the built-in
  # copy shortcut (Alt+c = password, Alt+u = username) and paste with Ctrl+V;
  # clear-after wipes the password from the clipboard 30s after a copy.
  xdg.configFile."rofi-rbw.rc".text = ''
    typer = wtype
    clear-after = 30
    typing-start-delay = 0.4
    typing-key-delay = 12
  '';
}
