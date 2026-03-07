{pkgs, ...}: {
  home.packages = with pkgs; [
    thunderbird
    gurk-rs
    element-desktop
    zapzap
    signal-desktop
  ];
}
