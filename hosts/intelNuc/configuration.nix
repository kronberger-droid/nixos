{ pkgs, ... }:

{
  imports = [
    ./hardware-configuration.nix
    ../common.nix
  ];

  environment.systemPackages = with pkgs; [
    droidcam
    android-tools
  ];

  # Gaming and graphics environment variables
  environment.sessionVariables = {
    # Force VSync for games to prevent screen tearing
    "__GL_SYNC_TO_VBLANK" = "1";
    "INTEL_DEBUG" = "sync";
  };

  programs.steam = {
    enable = true;
    remotePlay.openFirewall = true;
    dedicatedServer.openFirewall = true;
    gamescopeSession.enable = true;  # Optional: for better gaming experience
  };

  hardware.graphics = {
    enable = true;
    enable32Bit = true;

    extraPackages = with pkgs; [
      intel-media-driver
      vaapiIntel
      vaapiVdpau
      libvdpau-va-gl
    ];
    
    extraPackages32 = with pkgs.pkgsi686Linux; [
      intel-media-driver
      vaapiIntel
    ];
  };
  boot = {
    kernelPackages = pkgs.linuxPackages_latest;
    kernelModules = [ "v4l2loopback" ];
    extraModulePackages = [ pkgs.linuxPackages_latest.v4l2loopback ];
    kernelParams = [
      "mem_sleep_default=s2idle"
      "i915.enable_psr=0"  # Disable PSR which can cause screen tearing
    ];
    extraModprobeConfig = ''
      options v4l2loopback devices=1 video_nr=42 card_label="DroidCam" exclusive_caps=1
    '';
  };

  system.stateVersion = "24.11";
}
