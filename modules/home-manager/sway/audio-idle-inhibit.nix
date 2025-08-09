{ pkgs, ... }:
let
  sway-audio-idle-inhibit-v2 = pkgs.sway-audio-idle-inhibit.overrideAttrs (old: {
    version = "0.2.0";
    src = pkgs.fetchFromGitHub {
      owner = "ErikReider";
      repo = "SwayAudioIdleInhibit";
      rev = "v0.2.0";
      hash = "sha256-AIK/2CPXWie72quzCcofZMQ7OVsggNm2Cq9PBJXKyhw=";
    };
    buildInputs = (old.buildInputs or []) ++ [ pkgs.systemd ];
    nativeBuildInputs = (old.nativeBuildInputs or []) ++ [ pkgs.pkg-config ];
  });
in
{
  home.packages = [
    sway-audio-idle-inhibit-v2
  ];

  systemd.user.services.audio-idle-inhibit = {
    Unit = {
      Description = "audio-idle-inhibit service";
      After = [ "sway-session.target" "graphical-session.target" ];
      Wants = [ "sway-session.target" ];
    };

    Service = {
      ExecStart = "${sway-audio-idle-inhibit-v2}/bin/sway-audio-idle-inhibit";
      Restart = "on-failure";
      RestartSec = 5;
    };

    Install = {
      WantedBy = [ "sway-session.target" ];
    };
  };
}
