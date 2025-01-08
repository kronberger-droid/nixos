{ config, pkgs, ... }:

{
  home.packages = with pkgs; [
    megasync
  ];

  systemd.user.services.megasync = {
    Unit = {
      Description = "MEGAsync Daemon";
      After = "network.target";
    };
    Service = {
      ExecStart = "${pkgs.megasync}/bin/megasync";
      Restart = "on-failure";
      Environment = "DISPLAY=:0";
    };
    Install = {
      WantedBy = [ "default.target" ];
    };
  };
}
