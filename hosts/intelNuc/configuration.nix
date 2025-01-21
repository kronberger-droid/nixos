# Edit this configuration file to define what should be installed on
# your system.  Help is available in the configuration.nix(5) man page
# and in the NixOS manual (accessible by running ‘nixos-help’).

{ pkgs, ... }:

{
  nix.settings.experimental-features = [ "nix-command" "flakes" ];
   
  imports = [
    ./hardware-configuration.nix
  ];

  boot = {
    plymouth.enable = true;
    loader = {
      systemd-boot.enable = true;
      efi.canTouchEfiVariables = true;
    };
    initrd.verbose = false;
    kernelParams = [
      "quiet"
      "udev.log_level=3"
      "nowatchdog"
      "nmi_watchdog=0"
    ];
  };  
  networking.networkmanager.enable = true;
  
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
  
  services = {
    xserver.xkb = {
      layout = "us";
      variant = "";
    };
    hardware = {
      openrgb.enable = true;
    };
    pulseaudio.enable = false;
    printing.enable = true;
    pipewire = {
      enable = true;
      alsa.enable = true;
      alsa.support32Bit = true;
      pulse.enable = true;
    };
    gvfs.enable = true;
    keyd = {
      enable = true;
      keyboards = {
        default = {
          ids = [ "*"];
          settings = {
            main = {
              leftalt = "leftmeta";
              leftmeta = "leftalt";
            };
          };
        };
      };
    };
    gnome.gnome-keyring.enable = true;
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
          output_name = "HDMI-A-1";
          max_fps = 60;
          chooser_type = "simple";
          chooser_cmd = "${pkgs.slurp}/bin/slurp -f %o -or";
        };
      }; 
    };
  };
  
  hardware = {
    bluetooth = {
      enable = true;
      powerOnBoot = true;
    };
  };

  security = {
    pam = {
      services = {
        greetd.enableGnomeKeyring = true;
        swaylock = {};
      };
    };
    rtkit.enable = true;
    polkit.enable = true;
  };

  # Define a user account. Don't forget to set a password with ‘passwd’.
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
      git
      curl
      gparted
      bat
      zoxide
      nmap
    ];
  };
  
  nixpkgs.config = {
    allowUnfree = true;
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

  virtualisation.virtualbox.host.enable = true;
  
  programs.dconf.enable = true;
    
  system.stateVersion = "24.05";
}
