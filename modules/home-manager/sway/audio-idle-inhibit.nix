{ pkgs, ... }:
{
  home.packages = with pkgs; [
    sway-audio-idle-inhibit
  ];

  systemd.user.services.audio-idle-inhibit = {
    Unit = {
      Description = "audio-idle-inhibit service";
      After = [ "sway-session.target" "graphical-session.target" ];
      PartOf = [ "sway-session.target" ];
    };

    Service = {
      ExecStart = "${pkgs.sway-audio-idle-inhibit}/bin/sway-audio-idle-inhibit";
    };

    Install = {
      WantedBy = [ "sway-session.target" ];
    };
  };
}
