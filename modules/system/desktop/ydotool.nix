{...}: {
  # ydotoold injects input at the kernel /dev/uinput layer (evdev), unlike
  # wtype which uses the Wayland virtual-keyboard protocol. wtype uploads a
  # fresh keymap to the compositor for every out-of-layout character, and
  # Chromium/Firefox drop keys during that keymap swap -> long passwords
  # arrive mangled. ydotool sidesteps the keymap dance entirely, so rofi-rbw
  # types reliably into browsers. (See modules/home-manager/apps/bitwarden.nix.)
  programs.ydotool.enable = true;

  # The module creates the `ydotool` group and runs the daemon with a
  # 0660 root:ydotool socket, but does not add anyone to it. Without this,
  # the ydotool CLI gets permission-denied on /run/ydotoold/socket.
  users.users.kronberger.extraGroups = ["ydotool"];
}
