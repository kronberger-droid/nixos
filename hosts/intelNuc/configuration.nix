{
  pkgs,
  config,
  ...
}: {
  imports = [
    ./hardware-configuration.nix
    ../common.nix
    ../../modules/system/scx-schedulers.nix
    ../../modules/profiles/vpn-workstation.nix
  ];

  boot = {
    systemd-boot-defaults.enable = true;
    loader.efi.canTouchEfiVariables = true;
    kernelParams = [
      "console=tty1"
    ];
    extraModprobeConfig = ''
      options v4l2loopback devices=1 video_nr=42 card_label="DroidCam" exclusive_caps=1
    '';
  };

  environment.systemPackages = with pkgs; [
    droidcam
    android-tools
    lm_sensors
  ];

  environment.sessionVariables = {
    "__GL_SYNC_TO_VBLANK" = "1";
    "INTEL_DEBUG" = "sync";
  };

  programs.steam = {
    enable = true;
    extraPackages = [pkgs.sdl3];
    gamescopeSession.enable = true;
  };

  programs.gamemode = {
    enable = true;
    settings = {
      general = {
        renice = -10;
        inhibit_screensaver = 1;
        desiredgov = "performance";
        defaultgov = "schedutil";
      };
      gpu = {
        apply_gpu_optimisations = "accept-responsibility";
        gpu_device = 0;
        nv_powermizer_mode = 1;
        amd_performance_level = "high";
      };
      cpu = {
        park_cores = "no";
        pin_policy = "prefer-high-performance";
      };
      custom = {
        start = "${pkgs.writeShellScript "gamemode-start" ''
          # Set Intel GPU to maximum performance
          echo performance | sudo tee /sys/class/drm/card*/gt/gt*/rps_max_freq_mhz 2>/dev/null || true

          # Disable CPU power saving
          echo 0 | sudo tee /sys/devices/system/cpu/cpufreq/boost 2>/dev/null || true

          # Set I/O scheduler to performance for SSDs
          for disk in /sys/block/sd*/queue/scheduler; do
            echo mq-deadline | sudo tee "$disk" 2>/dev/null || true
          done
          for disk in /sys/block/nvme*/queue/scheduler; do
            echo none | sudo tee "$disk" 2>/dev/null || true
          done
        ''}";
        end = "${pkgs.writeShellScript "gamemode-end" ''
          # Reset Intel GPU to auto
          echo auto | sudo tee /sys/class/drm/card*/gt/gt*/rps_max_freq_mhz 2>/dev/null || true

          # Re-enable CPU power saving
          echo 1 | sudo tee /sys/devices/system/cpu/cpufreq/boost 2>/dev/null || true

          # Reset I/O scheduler to default
          for disk in /sys/block/sd*/queue/scheduler; do
            echo bfq | sudo tee "$disk" 2>/dev/null || true
          done
        ''}";
      };
    };
  };

  hardware.graphics = {
    enable = true;
    enable32Bit = true;

    extraPackages = with pkgs; [
      intel-media-driver
      intel-vaapi-driver
      libva-vdpau-driver
      libvdpau-va-gl
    ];

    extraPackages32 = with pkgs.pkgsi686Linux; [
      intel-media-driver
      intel-vaapi-driver
    ];
  };

  system.stateVersion = "24.11";
}
