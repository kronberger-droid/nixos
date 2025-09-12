{ pkgs, ... }:
{
  environment.systemPackages = [ pkgs.megacmd ];

  systemd.user.services.mega-cmd-server = {
    description = "MEGAcmd daemon";
    after = [ "graphical-session.target" ];
    serviceConfig = {
      ExecStart = "${pkgs.megacmd}/bin/mega-cmd-server";
      Restart = "on-failure";
      RestartSec = "10s";
      Type = "simple";
      Environment = "PATH=${pkgs.megacmd}/bin:$PATH";
    };
    wantedBy = [ "default.target" ];
  };
}
