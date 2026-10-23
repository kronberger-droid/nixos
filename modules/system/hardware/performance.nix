{
  pkgs,
  isNotebook ? false,
  ...
}: {
  # Zram configuration for better memory management. 50% everywhere: with
  # the high swappiness below, a small zram fills early and the rest spills
  # to the disk swap behind it (intelNuc's 20G LV, the laptops' swapfile).
  zramSwap = {
    enable = true;
    algorithm = "zstd";
    memoryPercent = 50;
    priority = 10;
  };

  # SSD optimizations. The schedule is in core/maintenance-schedule.nix.
  services.fstrim.enable = true;

  # Kernel parameters for better performance
  boot.kernel.sysctl = {
    # High on purpose. The first swap is zram, where swapping out a page
    # means compressing it in RAM. That is cheaper than dropping page cache
    # and reading it back through LUKS, so the kernel should prefer it. The
    # old value of 10 was the disk-swap advice and did the opposite.
    "vm.swappiness" = 180;

    # Improve responsiveness under memory pressure
    "vm.vfs_cache_pressure" = 50;

    # Better I/O scheduling for SSDs
    "vm.dirty_background_ratio" = 1;
    "vm.dirty_ratio" = 50;

    # Network performance optimizations
    "net.core.rmem_max" = 134217728;
    "net.core.wmem_max" = 134217728;
    "net.ipv4.tcp_rmem" = "4096 65536 134217728";
    "net.ipv4.tcp_wmem" = "4096 65536 134217728";
    "net.ipv4.tcp_congestion_control" = "bbr";

    # File system performance
    "fs.file-max" = 2097152;
  };

  # Boot optimizations
  boot = {
    tmp = {
      useTmpfs = true;
      tmpfsSize = "50%";
    };

    # Faster boot
    kernelParams =
      [
        "nowatchdog"
        "nmi_watchdog=0"
      ]
      ++ (
        if isNotebook
        then [
          "mem_sleep_default=s2idle"
        ]
        else []
      );

    blacklistedKernelModules = [
      "wdat_wdt"
    ];
  };

  # System optimization services
  # Journal retention is enforced continuously by journald via SystemMaxUse
  # (set per-host in journald.settings.Journal), so no extra vacuum timer is needed.
  systemd = {
    # Faster shutdown
    settings.Manager = {
      DefaultTimeoutStopSec = "10s";
      DefaultTimeoutStartSec = "10s";
    };
    # The system manager's default above does not propagate to user
    # instances, which keep systemd's 90 s. Anything in the session that
    # sits on SIGTERM therefore held shutdown for a minute and a half ("A
    # stop job is running for User Manager for UID 1001"); user@.service's
    # own 2 min bound sits outside that. The session's services all stop in
    # well under a second when they stop at all, so cap the user side the
    # same way.
    user.settings.Manager.DefaultTimeoutStopSec = "10s";
  };

  # OOM protection — kills largest process before kernel OOM freezes the system
  # earlyoom is preferred over systemd-oomd for desktop use (simpler, signal-based)
  services.earlyoom = {
    enable = true;
    freeMemThreshold = 5;
    # zram counts as swap; at 50% RAM zram (see zramSwap above) a 10% free-swap
    # threshold trips during normal heavy use and pops mako notifications.
    # 2% still protects against true low-swap conditions.
    freeSwapThreshold = 2;
    enableNotifications = true;
  };
  systemd.oomd.enable = false;

  # Not mkDefault: list definitions only merge at the highest priority
  # present, and nixpkgs adds "x-initrd.mount" to "/" at normal priority, so
  # a mkDefault here was dropped on every host. At normal priority it is
  # concatenated with that and with disko's "defaults".
  fileSystems."/".options = ["noatime"];
}
