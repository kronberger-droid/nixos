{ pkgs, config, inputs, ... }:

{
  imports = [
    ./hardware-configuration.nix
    ../common.nix
    inputs.pia.nixosModules."x86_64-linux".default
  ];

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

  boot = {
    loader = {
      systemd-boot.enable = true;
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
      vaapiIntel
      vaapiVdpau
      libvdpau-va-gl
    ];
    
    extraPackages32 = with pkgs.pkgsi686Linux; [
      intel-media-driver
      vaapiIntel
    ];
  };

  system.stateVersion = "24.11";
}
