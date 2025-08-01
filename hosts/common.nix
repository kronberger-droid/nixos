{ pkgs, host, ... }:
let
  outputName =
    if host == "intelNuc" then
      "HDMI-A-1"
    else if host ==  "t480s" || host =="spectre" then
      "eDP-1"
    else
      throw "Unknown hostname: ${host}";
in
{
  imports = [
    ../modules/system/megasync.nix
    ../modules/system/agenix.nix
    ../modules/system/keyd.nix
    ../modules/system/virtualisation.nix
    ../modules/system/gnome-keyring.nix
  ];

  programs.ssh.startAgent = true;
  
  systemd.user.services.ssh-agent.enable = true;

  nix = {
    settings.experimental-features = [ "nix-command" "flakes" ];
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

  boot = {
    loader = {
      systemd-boot.enable = true;
      efi.canTouchEfiVariables = true;
    };
    kernel.sysctl = {
      "vm.swappiness" = 10;
      "kvm.ignore_msrs" = 1;
    };
    kernelParams = [
      "nowatchdog"
      "nmi_watchdog=0"
    ];
    blacklistedKernelModules = [
      "wdat_wdt"
    ];
  };

  networking = {
    networkmanager.enable = true;
    wireless.enable = false;
    hostName = host;
    firewall.allowedTCPPorts = [ 22 53317 ];
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
    openssh = {
      enable = true;
      ports = [ 22 ];
    };

   # Add these to your configuration
    pulseaudio.enable = false;

    # Enhanced PipeWire configuration
    pipewire = {
      enable = true;
      alsa.enable = true;
      alsa.support32Bit = true;
      pulse.enable = true;  # This is important for PulseAudio compatibility
      jack.enable = true;
      wireplumber.enable = true;
    };

    avahi.enable = true;
    gvfs.enable = true;
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
    extraGroups = [ "networkmanager" "wheel" "audio" ];
    shell = pkgs.nushell;
    openssh.authorizedKeys.keys = [
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIEifxmkv6w0+8SGVET8DiDIjGMsGRPfpguSGwPU+MMax"
    ];
  };

  environment = {
    shells = [ pkgs.nushell ];
    variables = {
      EDITOR = "hx";
    };
    systemPackages = with pkgs; [
      helix
      neovim
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
      fd
      dust
      xdg-desktop-portal-gtk
      fwupd
      libcamera
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
}
