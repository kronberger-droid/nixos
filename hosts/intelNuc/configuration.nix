{
  pkgs,
  username,
  ...
}: {
  imports = [
    ./hardware-configuration.nix
    ../common.nix
    ../../modules/system/hardware/scx-schedulers.nix
    ../../modules/profiles/vpn-workstation.nix
    ../../modules/system/hardware/droidcam.nix
    ../../modules/system/boot/disk-layout.nix
  ];

  # Filesystems, swap, the LUKS entry and boot.resumeDevice all come out of
  # this; see the module for the layout and the install commands.
  disk-layout = {
    device = "/dev/disk/by-id/nvme-CT1000P3PSSD8_24344A99EF58";
    # 16G of RAM. The image is compressed and rarely full-size, but a
    # hibernate that fails only when memory is full is the worst kind.
    swapSize = "20G";
  };

  boot = {
    binfmt.emulatedSystems = ["aarch64-linux"];
    systemd-boot-defaults.enable = true;
    loader.efi.canTouchEfiVariables = true;
    kernelParams = [
      "console=tty1"
      # Disable memfd_secret kernel-wide. Any process holding secret memory
      # (Electron apps like Bitwarden do) makes the kernel refuse hibernation,
      # since secretmem pages must never hit disk but a hibernate image writes
      # all of RAM. LUKS-encrypted swap already protects the image at rest,
      # so the trade-off is negligible here.
      "secretmem.enable=0"
    ];
  };

  programs.steam = {
    enable = true;
    extraPackages = [pkgs.sdl3];
    gamescopeSession.enable = true;
    package = pkgs.steam.override {
      extraArgs = "-cef-disable-gpu";
    };
  };

  programs.gamemode = {
    enable = true;
    settings = {
      general = {
        renice = -10;
        inhibit_screensaver = 1;
        desiredgov = "performance";
        # intel_pstate runs in active mode here (the default; only the
        # laptops pass intel_pstate=active explicitly), which offers just
        # `performance` and `powersave`. `schedutil` does not exist in that
        # mode, so the restore step silently failed and the box stayed
        # pinned to `performance` after the first game.
        defaultgov = "powersave";
      };
      gpu = {
        apply_gpu_optimisations = "accept-responsibility";
        gpu_device = 1;
      };
      cpu = {
        park_cores = "no";
        pin_policy = "prefer-high-performance";
      };
      # No custom start/end scripts. The previous pair wrote 0 to
      # cpufreq/boost on game start (that disables turbo), a string into
      # rps_max_freq_mhz (an integer in MHz), and swapped the I/O scheduler to
      # a different one on exit than on entry, all through sudo from a session
      # daemon with no tty. desiredgov = performance above is the whole intent.
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

  # Limit build parallelism to keep the system responsive
  nix.settings = {
    cores = 12; # Leave 4 threads free for desktop responsiveness
    max-jobs = 2; # Max parallel derivation builds
  };

  # Always-on box, not a laptop — power the radio on boot so a trusted
  # bluetooth keyboard reconnects on its own (default is false for laptops).
  hardware.bluetooth.powerOnBoot = true;

  users.users.${username}.extraGroups = ["gamemode"];

  system.stateVersion = "26.11";
}
