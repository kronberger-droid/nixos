{
  pkgs,
  modulesPath,
  ...
}: {
  nix.settings.experimental-features = ["nix-command" "flakes"];

  imports = [
    (modulesPath + "/installer/sd-card/sd-image-aarch64.nix")
    ../../modules/system/desktop/keyd.nix
  ];

  # Compressed image to save disk
  sdImage.compressImage = true;

  # Pi 4 — mainline kernel (cached on cache.nixos.org, unlike linux-rpi)
  boot.kernelPackages = pkgs.linuxPackages_latest;
  hardware.graphics.enable = true;

  networking = {
    hostName = "mediaPi";
    networkmanager.enable = true;
  };

  # mDNS — so you can `ssh mediaPi@mediaPi.local`
  services.avahi = {
    enable = true;
    nssmdns4 = true;
    publish = {
      enable = true;
      addresses = true;
    };
  };

  time.timeZone = "Europe/Vienna";
  i18n.defaultLocale = "en_US.UTF-8";

  # ── User ──────────────────────────────────────────────
  users.users.mediaPi = {
    isNormalUser = true;
    extraGroups = ["wheel" "networkmanager" "video" "render"];
    shell = pkgs.nushell;
    openssh.authorizedKeys.keys = [
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIFijJelcEDGPlu9aDnjkLa4TWNXXJGeyHgw6ucANynAW"
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIFFXI1vd+dtthymv9vLy9QuoyGHuX5ZEkDXXSPfP6NVr"
    ];
  };

  environment = {
    shells = [pkgs.nushell];
    variables = {
      EDITOR = "hx";
      VISUAL = "hx";
    };
    systemPackages = with pkgs; [
      helix
      git
      wget
      foot        # terminal
      bluetuith   # bluetooth TUI
      networkmanagerapplet # wifi tray
    ];
  };

  # ── Desktop ───────────────────────────────────────────
  programs.sway = {
    enable = true;
    wrapperFeatures.gtk = true;
  };

  # Auto-login to mediaPi user
  services.greetd = {
    enable = true;
    settings.default_session = {
      command = "${pkgs.tuigreet}/bin/tuigreet --time --cmd ${pkgs.sway}/bin/sway";
      user = "greeter";
    };
  };

  nixpkgs.config.allowUnfree = true;
  programs.firefox = {
    enable = true;
    preferences = {
      "media.eme.enabled" = true; # Enable DRM (Widevine) for Netflix
    };
  };

  # ── Bluetooth ─────────────────────────────────────────
  hardware.bluetooth = {
    enable = true;
    powerOnBoot = true;
  };

  # ── Audio ─────────────────────────────────────────────
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    pulse.enable = true;
  };

  # ── SSH ───────────────────────────────────────────────
  services.openssh = {
    enable = true;
    ports = [22];
  };

  programs.ssh.startAgent = true;

  fonts.packages = with pkgs; [
    nerd-fonts.jetbrains-mono
    nerd-fonts.symbols-only
  ];

  system.stateVersion = "25.05";
}
