{...}: {
  # SCX (sched-ext) userspace scheduler for improved desktop responsiveness.
  # Requires kernel 6.12+ with sched_ext (currently on 6.18).
  #
  # Managed through the upstream `services.scx` module instead of a hand-rolled
  # systemd unit. The previous unit restart-looped a scheduler that the kernel
  # ejected during the CPU churn of shutdown (Restart=on-failure with no
  # meaningful start limit), re-attaching a BPF scheduler mid-teardown and
  # stalling poweroff. The upstream module rate-limits restarts and guards
  # startup on /sys/kernel/sched_ext existing.
  services.scx = {
    enable = true;
    # scx_lavd (Latency-Aware Virtual Deadline) prioritizes latency-critical
    # tasks for snappier interactive use (browsing, editing, gaming).
    scheduler = "scx_lavd";
  };
}
