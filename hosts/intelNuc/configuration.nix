{ pkgs, config, ... }:

{
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
  ];

  environment.sessionVariables = {
    "__GL_SYNC_TO_VBLANK" = "1";
    "INTEL_DEBUG" = "sync";
  };

  programs.steam = {
    enable = true;
    remotePlay.openFirewall = true;
    dedicatedServer.openFirewall = true;
    gamescopeSession.enable = true;
  };

  programs.gamemode = {
    enable = true;
    settings = {
      general = {
        renice = 10;
        inhibit_screensaver = 1;
      };
      gpu = {
        apply_gpu_optimisations = "accept-responsibility";
        gpu_device = 0;
      };
      cpu = {
        park_cores = "no";
        pin_policy = "prefer-high-performance";
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
    kernelPackages = pkgs.linuxPackages_latest;
    kernelModules = [ "v4l2loopback" ];
    extraModulePackages = [ pkgs.linuxPackages_latest.v4l2loopback ];
    kernelParams = [
      "i915.enable_psr=0"
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
