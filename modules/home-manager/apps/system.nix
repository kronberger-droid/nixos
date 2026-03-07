{pkgs, ...}: {
  home.packages = with pkgs; [
    ltunify
    bluetuith
    wiremix
  ];
}
