{ pkgs, ... }:
{
  environment.systemPackages = [ pkgs.megacmd ];

  systemd.user.services.mega-cmd-server = {
    description = "MEGAcmd daemon";
    serviceConfig = {
      ExecStart = "${pkgs.megacmd}/bin/mega-cmd-server";
      Restart = "on-failure";
      RestartSec = "10s";
      Type = "simple";
    };
    wantedBy = [ "default.target" ];
  };
}
