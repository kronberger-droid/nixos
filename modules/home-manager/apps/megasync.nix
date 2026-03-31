{pkgs, ...}: {
  systemd.user.services.mega-cmd-server = {
    Unit = {
      Description = "MEGAcmd daemon";
      After = ["graphical-session.target"];
      PartOf = ["graphical-session.target"];
    };
    Service = {
      ExecStart = "${pkgs.megacmd}/bin/mega-cmd-server";
      Restart = "on-failure";
      RestartSec = "10s";
      Environment = ["PATH=${pkgs.megacmd}/bin"];
    };
    Install = {
      WantedBy = ["graphical-session.target"];
    };
  };
}
