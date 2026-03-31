{
  pkgs,
  lib,
  isNotebook ? false,
  ...
}: {
  # Zram configuration for better memory management
  zramSwap = {
    enable = true;
    algorithm = "zstd";
    memoryPercent =
      if isNotebook
      then 50
      else 25;
    priority = 10;
  };

  # SSD optimizations
  services.fstrim = {
    enable = true;
    interval = "weekly";
  };

  # Kernel parameters for better performance
  boot.kernel.sysctl = {
    # Reduce swappiness to prefer RAM over swap
    "vm.swappiness" = 10;

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
  systemd = {
    services.journal-vacuum = {
      description = "Vacuum old journal entries";
      serviceConfig = {
        Type = "oneshot";
        ExecStart = "${pkgs.systemd}/bin/journalctl --vacuum-time=7d";
      };
    };

    timers.journal-vacuum = {
      description = "Weekly journal vacuum";
      wantedBy = ["timers.target"];
      timerConfig = {
        OnCalendar = "weekly";
        Persistent = true;
      };
    };

    # Faster shutdown
    settings.Manager = {
      DefaultTimeoutStopSec = "10s";
      DefaultTimeoutStartSec = "10s";
    };
  };

  # OOM protection — kills largest process before kernel OOM freezes the system
  services.earlyoom = {
    enable = true;
    freeMemThreshold = 5;
    freeSwapThreshold = 10;
    enableNotifications = true;
  };

  # Improved file system mount options (mkDefault so hardware-configuration.nix can override)
  fileSystems."/".options = lib.mkDefault ["noatime"];
}
