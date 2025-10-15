{ pkgs, isNotebook ? false, ... }:
{
  # Zram configuration for better memory management
  zramSwap = {
    enable = true;
    algorithm = "zstd";
    memoryPercent = if isNotebook then 50 else 25;
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
    tmp.cleanOnBoot = true;

    # Faster boot
    kernelParams = [
      "nowatchdog"
      "nmi_watchdog=0"
    ] ++ (if isNotebook then [
      "mem_sleep_default=s2idle"
    ] else []);

    blacklistedKernelModules = [
      "wdat_wdt"
    ];
  };

  # System optimization services
  systemd = {
    services = {
      # Clear logs older than 7 days
      systemd-journal-flush.serviceConfig.ExecStart = [
        ""
        "${pkgs.systemd}/bin/journalctl --vacuum-time=7d"
      ];
    };

    # Faster shutdown
    settings.Manager = {
      DefaultTimeoutStopSec = "10s";
      DefaultTimeoutStartSec = "10s";
    };
  };

  # Improved file system mount options
  fileSystems = {
    "/" = {
      options = [ "noatime" ];
    };
  };
}