
{ pkgs, ... }: {
  environment.systemPackages = with pkgs; [
    sway-audio-idle-inhibit
  ];

  systemd.user.services.audio-idle-inhibit= {
    description = "audio-idle-inhibit service";
    after = [ "sway.service" ];
    wantedBy = [ "default.target" ];  

    serviceConfig = {
      ExecStart = "${pkgs.sway-audio-idle-inhibit}/bin/sway-audio-idle-inhibit";
      Restart = "on-failure";
      RestartSec = "5s";  
    };
  };
}
