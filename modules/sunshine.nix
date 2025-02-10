{ lib, config, pkgs, ... }:
{
  services.sunshine = {
    enable = true;
    autoStart = true;
    capSysAdmin = true;
    openFirewall = true;
  };
  environment.systemPackages = with pkgs; [
    moonlight-qt
  ];
  hardware.opengl = {
    enable = true;
    extraPackages = with pkgs; [
      vpl-gpu-rt
    ];
  };
}
