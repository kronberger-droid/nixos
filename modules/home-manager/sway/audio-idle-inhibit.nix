{ pkgs, ... }:
{
  home.packages = with pkgs; [
    wayland-pipewire-idle-inhibit
  ];

  systemd.user.services.wayland-pipewire-idle-inhibit = {
    Unit = {
      Description = "Inhibit idle when audio is playing";
      After = [ "pipewire.service" "graphical-session.target" ];
      PartOf = [ "graphical-session.target" ];
    };

    Service = {
      ExecStart = "${pkgs.wayland-pipewire-idle-inhibit}/bin/wayland-pipewire-idle-inhibit";
      Restart = "on-failure";
      RestartSec = 5;
    };

    Install = {
      WantedBy = [ "graphical-session.target" ];
    };
  };
}
