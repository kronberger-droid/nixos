{
  pkgs,
  config,
  ...
}: {
  imports = [
    ./hardware-configuration.nix
    ../common.nix
    ../../modules/system/scx-schedulers.nix
    # ../../modules/system/copyparty.nix  # Disabled for now
  ];

  services.pia = {
    enable = true;
    authUserPassFile = config.age.secrets.pia-credentials.path;
  };

  services.tuwien-vpn = {
    enable = true;
    passwordFile = config.age.secrets.tuwien-vpn-password.path;
  };

  environment.systemPackages = with pkgs; [
    droidcam
    android-tools
    lm_sensors # Temperature monitoring
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
        renice = -10; # Higher priority for games (lower value = higher priority)
        inhibit_screensaver = 1;
        desiredgov = "performance"; # Switch to performance CPU governor
        defaultgov = "schedutil"; # Return to balanced governor when done
      };
      gpu = {
        apply_gpu_optimisations = "accept-responsibility";
        gpu_device = 0;
        nv_powermizer_mode = 1; # Prefer maximum performance
        amd_performance_level = "high"; # AMD GPU performance mode
      };
      cpu = {
        park_cores = "no"; # Keep all cores active
        pin_policy = "prefer-high-performance"; # Pin to high-performance cores
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

  boot = {
    initrd.systemd.enable = true; # Faster boot with systemd in initrd
    loader = {
      systemd-boot = {
        enable = true;
        editor = false; # Disable boot menu editor for security
        configurationLimit = 20; # Limit number of stored generations
      };
      timeout = 1; # Fast boot menu timeout
      efi.canTouchEfiVariables = true;
    };
    kernelPackages = pkgs.linuxPackages;
    kernelParams = [
      # Commented out for testing - may have caused sleep issues
      # "i915.enable_psr=0"
      # "i915.enable_dc=0"  # Disable display power-saving states
      # "i915.enable_fbc=0"  # Disable framebuffer compression
      "console=tty1"
    ];
    extraModprobeConfig = ''
      options v4l2loopback devices=1 video_nr=42 card_label="DroidCam" exclusive_caps=1
    '';
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
