{pkgs, ...}: {
  home.packages = with pkgs; [
    seahorse
    bitwarden-desktop
    rofi-rbw-wayland
    rbw
    openssl
    libsecret
  ];
}
