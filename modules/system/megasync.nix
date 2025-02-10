{ pkgs, ... }: {
  environment.systemPackages = with pkgs; [
    megasync
  ];

  systemd.user.services.megasync = {
    description = "MegaSync Service (Wait for Waybar)";
    after = [ "waybar.service" ];
    wants = [ "waybar.service" ];
    wantedBy = [ "default.target" ];  

    serviceConfig = {
      ExecStartPre = "${pkgs.bash}/bin/bash -c 'while ! ${pkgs.procps}/bin/pgrep -x .waybar-wrapped > /dev/null; do sleep 5; done'";
      ExecStart = "${pkgs.megasync}/bin/megasync";
      Restart = "on-failure";
      RestartSec = "5s";  
    };
  };
}
