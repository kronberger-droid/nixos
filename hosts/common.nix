{ pkgs, host,  ... }:
let
  outputName =
    if host == "intelNuc" then
      "HDMI-A-1"
    else if host == "t480s" || host == "spectre" then
      "eDP-1"
    else if host == "portable" then
      "*"
    else
      throw "Unknown hostname: ${host}";
in
{
  imports = [
    ../modules/system/megasync.nix
    # ../modules/system/agenix.nix
    ../modules/system/keyd.nix
    ../modules/system/virtualisation.nix
    ../modules/system/gnome-keyring.nix
    ../modules/system/wireplumber-config.nix
    ../modules/system/performance.nix
    ../modules/system/security.nix
    ../modules/system/power-management.nix
  ];


  nix = {
    settings = {
      experimental-features = [ "nix-command" "flakes" ];
      auto-optimise-store = true;
      max-free = 1073741824; # 1GB
      min-free = 134217728;  # 128MB
      substituters = [
        "https://cache.nixos.org/"
        "https://nix-community.cachix.org"
      ];
      trusted-public-keys = [
        "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY="
        "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
      ];
    };
    gc = {
      automatic = true;
      dates = "weekly";
      options = "--delete-older-than 30d";
    };
    optimise = {
      automatic = true;
      dates = [ "03:45" ];
    };
  };

  nixpkgs.overlays = [
    (final: prev: {
      brave = prev.brave.override {
        commandLineArgs = [
          "--password-store=gnome-keyring"
        ];
      };
    })
  ];

  networking = {
    networkmanager = {
      enable = true;
      # Faster DNS resolution
      insertNameservers = [ "1.1.1.1" "1.0.0.1" "8.8.8.8" ];
      # Better connection management
      settings = {
        main = {
          dns = "systemd-resolved";
          rc-manager = "symlink";
        };
        connection = {
          mdns = 2;
          "ipv6.method" = "auto";
          "ipv6.addr-gen-mode" = "stable-privacy";
        };
        wifi = {
          "scan-rand-mac-address" = "yes";
        };
        ethernet = {
          "cloned-mac-address" = "random";
        };
      };
    };
    wireless.enable = false;
    hostName = host;

    # Enable systemd-resolved for better DNS performance
    nameservers = [ "1.1.1.1" "1.0.0.1" ];
    # IPv6 privacy extensions
    enableIPv6 = true;
  };

  time.timeZone = "Europe/Vienna";

  i18n = {
    defaultLocale = "en_US.UTF-8";
    extraLocaleSettings = {
      LC_ADDRESS = "de_AT.UTF-8";
      LC_IDENTIFICATION = "de_AT.UTF-8";
      LC_MEASUREMENT = "de_AT.UTF-8";
      LC_MONETARY = "de_AT.UTF-8";
      LC_NAME = "de_AT.UTF-8";
      LC_NUMERIC = "de_AT.UTF-8";
      LC_PAPER = "de_AT.UTF-8";
      LC_TELEPHONE = "de_AT.UTF-8";
      LC_TIME = "de_AT.UTF-8";
    };
  };

  security = {
    polkit.enable = true;
    rtkit.enable = true;
    sudo-rs.enable = true;
  };

  services = {
    fwupd.enable = true;
    thermald.enable = true;
    flatpak.enable = true;
    resolved.enable = true;
    
    journald.extraConfig = ''
      Storage=persistent
      Compress=yes
      SystemMaxUse=1G
      RuntimeMaxUse=100M
    '';

    pulseaudio.enable = false;
    pipewire = {
      enable = true;
      alsa.enable = true;
      alsa.support32Bit = true;
      pulse.enable = true;
      jack.enable = true;
      wireplumber.enable = true;
    };

    avahi = {
      enable = true;
      nssmdns4 = true;
      nssmdns6 = true;
    };
    gvfs.enable = true;
    udisks2.enable = true;
    upower.enable = true;
  };

  hardware = {
    bluetooth = {
      enable = true;
      powerOnBoot = true;
    };
    firmware = [ pkgs.linux-firmware ];
    graphics = {
      enable = true;
      enable32Bit = true;
    };
  };
  
  xdg.portal = {
    enable = true;
    extraPortals = [ pkgs.xdg-desktop-portal-gtk ];
    config = {
      common.default = [ "wlr" "gtk" ];
    };
    wlr = {
      enable = true;
      settings = {
        screencast = {
          output_name = outputName;
          max_fps = 60;
          chooser_type = "simple";
          chooser_cmd = "${pkgs.slurp}/bin/slurp -f %o -or";
        };
      };
    };
  };

  virtualisation.spiceUSBRedirection.enable = true;

  programs = {
    xwayland.enable = true;
    dconf.enable = true;
    seahorse.enable = true;
  };
  users.users.kronberger = {
    createHome = true;
    isNormalUser = true;
    description = "Kronberger";
    extraGroups = [ "networkmanager" "wheel" "audio" "video" ];
    shell = pkgs.nushell;
    openssh.authorizedKeys.keys = [
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIFijJelcEDGPlu9aDnjkLa4TWNXXJGeyHgw6ucANynAW"
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIFFXI1vd+dtthymv9vLy9QuoyGHuX5ZEkDXXSPfP6NVr"
    ];
  };

  environment = {
    shells = [ pkgs.nushell ];
    variables = {
      EDITOR = "hx";
    };
    systemPackages = with pkgs; [
      helix
      git
      curl
      gparted
      bat
      zoxide
      nmap
      usbutils
      exfat
      libsecret
      busybox
      tree
      wirelesstools
      popsicle
      eza
      ripgrep
      rip2
      fd
      skim
      xcp
      dust
      fwupd
      libcamera
      nixpkgs-review
      cryptsetup
      xorg.xhost
      xorg.xauth
      woeusb
      clamav
    ];
  };

  fonts.packages = with pkgs; [
    nerd-fonts.jetbrains-mono
    nerd-fonts.symbols-only
    dejavu_fonts
    noto-fonts
    noto-fonts-cjk-sans
    noto-fonts-emoji
    liberation_ttf
    cm_unicode
  ];

  nixpkgs.config.allowUnfree = true;

  powerManagement = {
    enable = true;
    resumeCommands = ''
      systemctl restart thermald || true
    '';
  };
}
