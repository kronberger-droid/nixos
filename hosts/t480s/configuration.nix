{ config, pkgs, lib, host, ... }:
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
  nix.settings.experimental-features = [ "nix-command" "flakes" ];

  imports = [
    ./hardware-configuration.nix
  ];

  boot = {
    loader = {
      systemd-boot.enable = true;
      efi.canTouchEfiVariables = true;
    };
    plymouth.enable = true;
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
    pam.services.greetd.enableGnomeKeyring = true;
    rtkit.enable = true;
    pam.services.swaylock = {};
  };

  services = {
    xserver = {
      xkb = {
        layout = "us";
        variant = "";
      };
    };

    printing.enable = true;
    
    "06cb-009a-fingerprint-sensor" = {                                 
      enable = true;                                                            
      backend = "python-validity";                                              
    };      

    pipewire = {
      enable = true;
      alsa = {
        enable = true;
        support32Bit = true;
      };
      pulse.enable = true;
    };

    gvfs.enable = true;
    gnome.gnome-keyring.enable = true;
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
    nix-ld.enable = true;
  };

  users.users.kronberger = {
    createHome = true;
    isNormalUser = true;
    description = "Kronberger";
    extraGroups = [ "networkmanager" "wheel" "vboxusers" ];
    shell = pkgs.nushell;
  };

  environment = {
    shells = [ pkgs.nushell ];
    variables.EDITOR = "hx";
    systemPackages = with pkgs; [
      helix
      wget
      git
      curl
      gparted
      bat
      zoxide
      neovim
      nmap
      libfprint
      usbutils
    ];
  };

  virtualisation.virtualbox.host = {
    enable = true;
    enableExtensionPack = true;
  };

  programs.dconf.enable = true;

  nixpkgs.config.allowUnfree = true;

  fonts.packages = with pkgs; [
    nerd-fonts.jetbrains-mono
    dejavu_fonts
    noto-fonts
    noto-fonts-cjk-sans
    noto-fonts-emoji
    liberation_ttf
  ];

  system.stateVersion = "24.05";
}
