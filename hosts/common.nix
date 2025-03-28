{ pkgs, host, inputs, ... }:
let
  outputName =
    if host == "intelNuc" then
      "HDMI-A-1"
    else if host == "t480s" then
      "eDP-1"
    else
      throw "Unknown hostname: ${host}";
in
{
  imports = [
    ../modules/system/megasync.nix
    ../modules/system/agenix.nix
    ../modules/system/keyd.nix
  ];

  nix.settings.experimental-features = [ "nix-command" "flakes" ];

  boot = {
    loader = {
      systemd-boot.enable = true;
      efi.canTouchEfiVariables = true;
    };
    plymouth.enable = true;
    initrd.verbose = false;
    kernelParams = [
      "quiet"
      "udev.log_level=3"
      "nowatchdog"
      "nmi_watchdog=0"
    ];
  };

  networking = {
    networkmanager.enable = true;
    hostName = host;
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
    # pam.services.greetd.enableGnomeKeyring = true;
    rtkit.enable = true;
    pam.services = {
      swaylock = {};
      greetd.enableGnomeKeyring = true;
      greetd-password.enableGnomeKeyring = true;
      login.enableGnomeKeyring = true;  
    };
  };

  services = {
    openssh = {
      enable = true;
      settings = {
        X11Forwarding = true;
      };
    };
    gnome.gnome-keyring.enable = true;
    pulseaudio.enable = false;
    avahi.enable = true;
    pipewire = {
      enable = true;
      alsa = {
        enable = true;
        support32Bit = true;
      };
      pulse.enable = true;
    };
    gvfs.enable = true;
    upower.enable = true;
    dbus.packages = [
      pkgs.gnome-keyring
      pkgs.gcr
    ];
  };

  hardware = {
    bluetooth = {
      enable = true;
      powerOnBoot = true;
    };
    firmware = [ pkgs.linux-firmware ];
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

  programs = {
    xwayland.enable = true;
    dconf.enable = true;
  };

  users.users.kronberger = {
    createHome = true;
    isNormalUser = true;
    description = "Kronberger";
    extraGroups = [ "networkmanager" "wheel" ];
    shell = pkgs.nushell;
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
  ];

  nixpkgs.config.allowUnfree = true;
}
