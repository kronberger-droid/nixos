{ pkgs, ... }:{
  home.packages = with pkgs; [
    bitwarden
    rbw-rofi-wayland
  ];
  programs.rbw = {
    enable = true;
    settings = {
      email = "kronberger@proton.me";
    };
  };
}
