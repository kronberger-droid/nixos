{
  config,
  lib,
  pkgs,
  osConfig ? null,
  ...
}: {
  # rbw only reads an existing device_id and writes one when it is missing,
  # so a read-only link to the agenix copy is safe. Set only on hosts that
  # have their secrets/rbw-device-id-<host>.age.
  home.file.".local/share/rbw/device_id" = lib.mkIf ((osConfig.age.secrets or {}) ? rbw-device-id) {
    source = config.lib.file.mkOutOfStoreSymlink osConfig.age.secrets.rbw-device-id.path;
  };

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
  # When the entry has a TOTP, rofi-rbw automatically copies it to the
  # clipboard right after typing the password (built-in behaviour, since the
  # default targets include "password"). use-notify-send surfaces a mako
  # toast so we know the code is waiting in the clipboard, ready to paste.
  #
  # Caveat: Chromium-based browsers (Helium, Brave) drop/stutter synthetic
  # keystrokes from any typer — an upstream Chromium/Wayland input limitation,
  # cf. https://github.com/atx/wtype/issues/31. For those, use the built-in
  # copy shortcut (Alt+c = password, Alt+u = username) and paste with Ctrl+V;
  # clear-after wipes the password from the clipboard 30s after a copy.
  #
  # typing-start-delay is whole seconds, not the milliseconds rofi-rbw 1.7.0's
  # changelog claims: the parser was switched to int, but the wtype typer
  # still hands the value straight to sleep(). A fractional value makes
  # argparse bail with exit 2 before any window appears, which is how the
  # keybinding went silently dead; 400 would sleep for almost seven minutes.
  # 1 is the smallest value that keeps the "wait for focus to return from
  # rofi" behaviour. Revisit when upstream divides by 1000 like it already
  # does for action-sequence-delay.
  xdg.configFile."rofi-rbw.rc".text = ''
    typer = wtype
    clear-after = 30
    typing-start-delay = 1
    typing-key-delay = 12
    use-notify-send = true
  '';
}
