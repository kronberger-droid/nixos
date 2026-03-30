{pkgs, ...}: {
  nix.settings.experimental-features = ["nix-command" "flakes"];

  imports = [
    ./hardware-configuration.nix
  ];

  boot.loader.grub.enable = false;
  boot.loader.generic-extlinux-compatible.enable = true;

  # GPU — use V3D driver for hardware video decode
  hardware.graphics.enable = true;

  networking.hostName = "nixos-pi";
  networking.networkmanager.enable = true;

  time.timeZone = "Europe/Vienna";

  i18n.defaultLocale = "en_US.UTF-8";

  users.users.devPi = {
    isNormalUser = true;
    extraGroups = ["wheel" "networkmanager" "video" "render"];
    shell = pkgs.nushell;
    openssh.authorizedKeys.keys = [
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAINEy1NxD4g5ZjbOG40mE3GUAlWFxBEJ+dtFrjNW9C2WR kronberger@devpi"
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIFijJelcEDGPlu9aDnjkLa4TWNXXJGeyHgw6ucANynAW"
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIFFXI1vd+dtthymv9vLy9QuoyGHuX5ZEkDXXSPfP6NVr"
    ];
  };

  environment = {
    shells = [pkgs.nushell];
    variables = {
      EDITOR = "hx";
      VISUAL = "hx";
      GIT_EDITOR = "hx";
    };
    systemPackages = with pkgs; [
      helix
      git
      wget
    ];
  };

  programs = {
    ssh.startAgent = true;
  };

  # Cage kiosk compositor — auto-login and launch Chromium fullscreen
  services.cage = {
    enable = true;
    user = "devPi";
    program = "${pkgs.chromium}/bin/chromium --enable-features=UseOzonePlatform --ozone-platform=wayland --enable-gpu-rasterization --enable-zero-copy";
  };

  # Chromium with Widevine for Netflix DRM
  nixpkgs.config.allowUnfree = true;
  programs.chromium = {
    enable = true;
    enablePlasmaBrowserIntegration = false;
    extensions = [
      "cjpalhdlnbpafiamejdnhcphjbkeiagm" # uBlock Origin
    ];
  };

  services.openssh = {
    enable = true;
    ports = [22];
  };

  # PipeWire for audio
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    pulse.enable = true;
  };

  fonts.packages = with pkgs; [
    nerd-fonts.jetbrains-mono
    nerd-fonts.symbols-only
  ];

  system.stateVersion = "25.05";
}
