{ pkgs, ... }:
{
  # ensure the binary is available
  environment.systemPackages = [ pkgs.megacmd ];

  # define a user-level service
  systemd.user.services.mega-cmd-server = {
    description = "MEGAcmd daemon";
    after = [ "graphical-session.target" ];
    wants = [ "graphical-session.target" ];
    serviceConfig = {
      ExecStart = "${pkgs.megacmd}/bin/mega-cmd-server";
      Restart = "on-failure";
    };
    wantedBy = [ "default.target" ];
  };
}
