{pkgs, ...}: {
  # SCX (sched-ext) userspace scheduler for improved desktop responsiveness.
  # Requires kernel 6.12+ with sched_ext (currently on 6.18).
  #
  # Managed through the upstream `services.scx-loader` module, which replaced
  # `services.scx` in nixpkgs. scx_loader is a daemon that starts
  # `default_sched` at boot and swaps schedulers at runtime over D-Bus
  # (`scxctl`), instead of a unit that wraps one scheduler process. The
  # hand-rolled unit before either of them restart-looped a scheduler that
  # the kernel ejected during the CPU churn of shutdown (Restart=on-failure
  # with no meaningful start limit), re-attaching a BPF scheduler
  # mid-teardown and stalling poweroff.
  services.scx-loader = {
    enable = true;
    # The module defaults to scx.rustscheds, which carries scx_bpfland and is
    # a fraction of scx.full's closure.
    schedsPackages = [pkgs.scx.rustscheds];
    # scx_bpfland targets the same interactive workloads scx_lavd did, but
    # with a much smaller design: no autopilot, topology or power-mode
    # machinery, and all policy in BPF with Rust only handling CLI and stats.
    #
    # The move off scx_lavd is about shutdown. Tearing down a sched_ext
    # struct_ops calls synchronize_rcu_tasks(), which blocks in
    # TASK_UNINTERRUPTIBLE, so the process cannot be signalled and SIGKILL
    # bounces off it. During shutdown, tasks are being frozen at the same
    # moment the scheduler unloads, so the grace period cannot close and the
    # unload cannot finish. systemd burned 41s on scx.service in three of the
    # last five shutdowns, and the stalled grace period took /boot's unmount
    # and the final systemd-shutdown phase down with it (~2 min total).
    # Fewer BPF programs and maps means less struct_ops teardown work.
    config.default_sched = "scx_bpfland";
  };
}
