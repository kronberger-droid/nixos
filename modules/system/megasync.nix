{ pkgs, ... }:
{
  environment.systemPackages = [ pkgs.megacmd ];

  systemd.user.services.mega-cmd-server = {
    description = "MEGAcmd daemon";
    after = [ "sway-session.target" ];
    serviceConfig = {
      ExecStart = "${pkgs.megacmd}/bin/mega-cmd-server";
      Restart = "on-failure";
      RestartSec = "10s";
      Type = "simple";
      Environment = [ "PATH=${pkgs.megacmd}/bin" ];
    };
    wantedBy = [ "sway-session.target" ];
  };
}
