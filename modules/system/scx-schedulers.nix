{pkgs, ...}: {
  # SCX (Sched-Ext) Schedulers for improved desktop responsiveness
  # Requires kernel 6.12+ (currently using 6.18)

  # Install scx scheduler packages (rustscheds includes scx_lavd)
  environment.systemPackages = with pkgs; [
    scx.rustscheds
  ];

  # Enable scx_lavd scheduler via systemd service
  # scx_lavd (Latency-Aware Virtual Deadline) prioritizes latency-critical
  # tasks for snappier interactive use (browsing, editing, gaming).
  systemd.services.scx-lavd = {
    description = "SCX LAVD Scheduler for Desktop Responsiveness";
    wantedBy = ["multi-user.target"];
    after = ["basic.target"];
    serviceConfig = {
      Type = "simple";
      ExecStart = "${pkgs.scx.rustscheds}/bin/scx_lavd";
      Restart = "on-failure";
      RestartSec = "5s";
      # Run with elevated priority
      Nice = -10;
    };
  };
}
