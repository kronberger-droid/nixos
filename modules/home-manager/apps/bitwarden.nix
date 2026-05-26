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

  # rofi-rbw types via wtype with NO delay by default (key/start delay = 0),
  # which makes browsers (Helium/Chromium, Firefox) drop or reorder characters
  # and lose leading keys before focus returns -> wrong passwords typed.
  # A per-key delay + a start delay make typing reliable. Tune if needed.
  xdg.configFile."rofi-rbw.rc".text = ''
    typing-start-delay = 0.4
    typing-key-delay = 12
  '';
}
