{ pkgs, ... }:
{
  environment.systemPackages = [ pkgs.megacmd ];

  systemd.user.services.mega-cmd-server = {
    description = "MEGAcmd daemon";
    after = [ "mnt-data.mount" ];
    requisite = [ "mnt-data.mount" ];
    serviceConfig = {
      ExecStart = "${pkgs.megacmd}/bin/mega-cmd-server";
      Restart = "on-failure";
      RestartSec = "10s";
      Type = "simple";
    };
    wantedBy = [ "default.target" ];
  };
}
