{
  config,
  lib,
  ...
}: let
  cfg = config.services.arrabbiata;
in {
  options.services.arrabbiata = {
    enable = lib.mkEnableOption "arrabbiata pomodoro timer service";

    package = lib.mkOption {
      type = lib.types.package;
      description = "The arrabbiata package to use";
    };

    port = lib.mkOption {
      type = lib.types.port;
      default = 5000;
      description = "Port to listen on";
    };
  };

  config = lib.mkIf cfg.enable {
    systemd.services.arrabbiata = {
      description = "Arrabbiata Pomodoro Timer";
      wantedBy = ["multi-user.target"];
      after = ["network.target"];

      serviceConfig = {
        ExecStart = "${cfg.package}/bin/arrabbiata";
        Restart = "on-failure";
        RestartSec = 5;
        DynamicUser = true;
        StateDirectory = "arrabbiata";
        WorkingDirectory = "/var/lib/arrabbiata";
      };

      environment = {
        ASPNETCORE_URLS = "http://0.0.0.0:${toString cfg.port}";
      };
    };

    networking.firewall.allowedTCPPorts = [cfg.port];
  };
}
