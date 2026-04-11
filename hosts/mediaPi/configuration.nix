{
  pkgs,
  modulesPath,
  ...
}: {
  nix.settings.experimental-features = ["nix-command" "flakes"];

  imports = [
    (modulesPath + "/installer/sd-card/sd-image-aarch64.nix")
  ];

  # Compressed image to save disk
  sdImage.compressImage = true;

  # Pi 4 firmware & GPU
  hardware.raspberry-pi."4" = {
    fkms-3d.enable = true;
  };
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
    ];
  };

  # ── Kiosk ─────────────────────────────────────────────
  services.cage = {
    enable = true;
    user = "mediaPi";
    program = toString (pkgs.writeShellScript "kiosk-launch" ''
      ${pkgs.chromium}/bin/chromium \
        --kiosk \
        --enable-features=UseOzonePlatform \
        --ozone-platform=wayland \
        --enable-gpu-rasterization \
        --enable-zero-copy \
        --noerrdialogs \
        --disable-infobars \
        --no-first-run \
        file:///home/mediaPi/.local/share/kiosk/start.html
    '');
  };

  nixpkgs.config.allowUnfree = true;
  programs.chromium = {
    enable = true;
    extensions = [
      "cjpalhdlnbpafiamejdnhcphjbkeiagm" # uBlock Origin
    ];
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
