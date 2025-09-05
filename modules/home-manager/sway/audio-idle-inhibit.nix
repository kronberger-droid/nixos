{ pkgs, ... }:
{
  home.packages = with pkgs; [
    sway-audio-idle-inhibit
  ];

  systemd.user.services.audio-idle-inhibit = {
    Unit = {
      Description = "audio-idle-inhibit service";
      After = [ "sway-session.target" "graphical-session.target" ];
      Wants = [ "sway-session.target" ];
    };

    Service = {
      ExecStart = "${pkgs.sway-audio-idle-inhibit}/bin/sway-audio-idle-inhibit";
      Restart = "on-failure";
      RestartSec = 5;
    };

    Install = {
      WantedBy = [ "sway-session.target" ];
    };
  };
}
