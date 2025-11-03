{ pkgs, ... }: {
  home.packages = with pkgs; [
    bitwarden
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
}
