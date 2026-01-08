{pkgs, ...}: {
  # SCX (Sched-Ext) Schedulers for improved desktop responsiveness
  # Requires kernel 6.12+ (currently using 6.17.8)

  # Install scx scheduler packages (rustscheds includes scx_rusty)
  environment.systemPackages = with pkgs; [
    scx.rustscheds
  ];

  # Enable scx_rusty scheduler via systemd service
  # scx_rusty is optimized for desktop workloads with better responsiveness
  systemd.services.scx-rusty = {
    description = "SCX Rusty Scheduler for Desktop Performance";
    wantedBy = ["multi-user.target"];
    after = ["basic.target"];
    serviceConfig = {
      Type = "simple";
      ExecStart = "${pkgs.scx.rustscheds}/bin/scx_rusty";
      Restart = "on-failure";
      RestartSec = "5s";
      # Run with elevated priority
      Nice = -10;
    };
  };
}
