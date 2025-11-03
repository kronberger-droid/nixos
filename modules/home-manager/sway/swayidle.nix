{ pkgs, ... }:

{
  home.packages = with pkgs; [
    swayidle
    libnotify
  ];

  services.swayidle = {
    enable = true;
    systemdTarget = "sway-session.target";
    timeouts = [
      {
        timeout = 395;
        command = "${pkgs.libnotify}/bin/notify-send 'Locking in 5 seconds' -t 5000";
      }
      {
        timeout = 400;
        command = "${pkgs.swaylock-effects}/bin/swaylock -f &";
      }
      {
        timeout = 460;
        command = "${pkgs.sway}/bin/swaymsg 'output * dpms off'";
        resumeCommand = "${pkgs.sway}/bin/swaymsg 'output * dpms on'";
      }
      {
        timeout = 560;
        command = "${pkgs.systemd}/bin/systemctl suspend";
      }
    ];
    events = [
      {
        event = "before-sleep";
        command = "${pkgs.swaylock-effects}/bin/swaylock -f &";
      }
    ];
  };
}
