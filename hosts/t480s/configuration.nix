# Edit this configuration file to define what should be installed on
# your system.  Help is available in the configuration.nix(5) man page
# and in the NixOS manual (accessible by running ‘nixos-help’).

{ pkgs, lib, host, ... }:
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

  # Bootloader.
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

  # Set your time zone.
  time.timeZone = "Europe/Vienna";

  # Select internationalisation properties.
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
  
  security.polkit.enable = true;

  # Configure keymap in X11
  services.xserver.xkb = {
    layout = "us";
    variant = "";
  };
  # Enable CUPS to print documents.
  services.printing.enable = true;

  xdg.portal = {
    enable = true;
    extraPortals = [ pkgs.xdg-desktop-portal-gtk ]; # Adds GTK portal for GTK-based applications
      config = {
        common.default = [ "wlr" "gtk" ]; # Sets the default portal order
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
  
  # Enable sound with pipewire.
  services.pulseaudio.enable = false;

  hardware.bluetooth = {
    enable = true;
    powerOnBoot = true;
  };

  hardware.firmware = [ pkgs.linux-firmware ];

  services.gvfs.enable = true;
  services.gnome.gnome-keyring.enable = true;
  security.pam.services.greetd.enableGnomeKeyring = true;
   
  security.rtkit.enable = true;

  security.pam.services.swaylock = {};
  
  programs.xwayland.enable = true;

  services.pipewire = {
    enable = true;
    alsa.enable = true;
    alsa.support32Bit = true;
    pulse.enable = true;
    # If you want to use JACK applications, uncomment this
    #jack.enable = true;

    # use the example session manager (no others are packaged yet so this is enabled by default,
    # no need to redefine it in your config for now)
    #media-session.enable = true;
  };

  # Enable touchpad support (enabled default in most desktopManager).
  # services.xserver.libinput.enable = true;

  # Define a user account. Don't forget to set a password with ‘passwd’.
  users.users.kronberger = {
    createHome = true;
    isNormalUser = true;
    description = "Kronberger";
    extraGroups = [ "networkmanager" "wheel" "vboxusers" ];
    shell = pkgs.nushell;  
  };
  
  environment.shells = [ pkgs.nushell ];
  
  environment.variables.EDITOR = "hx";
  
  # Allow unfree packages
  nixpkgs.config = {
    allowUnfree = true;
  };

  programs.nix-ld.enable = true;
  
  fonts.packages = with pkgs; [
    nerd-fonts.jetbrains-mono
    dejavu_fonts # mind the underscore! most of the packages are named with a hypen, not this one however
    noto-fonts
    noto-fonts-cjk-sans
    noto-fonts-emoji
    liberation_ttf
  ];

  # List packages installed in system profile. To search, run:
  # $ nix search wget
  environment.systemPackages = with pkgs; [
    helix # Do not forget to add an editor to edit configuration.nix! The Nano editor is also installed by default.
    wget
    git
    curl
    gparted
    bat
    zoxide
    neovim
    nmap
  ];

  virtualisation.virtualbox.host.enable = true;
  virtualisation.virtualbox.host.enableExtensionPack = true;

  programs.dconf.enable = true;  
  
  # Some programs need SUID wrappers, can be configured further or are
  # started in user sessions.
  # programs.mtr.enable = true;
  # programs.gnupg.agent = {
  #   enable = true;
  #   enableSSHSupport = true;
  # };

  # List services that you want to enable:

  # Enable the OpenSSH daemon.
  # services.openssh.enable = true;

  # Open ports in the firewall.
  # networking.firewall.allowedTCPPorts = [ ... ];
  # networking.firewall.allowedUDPPorts = [ ... ];
  # Or disable the firewall altogether.
  # networking.firewall.enable = false;

  # This value determines the NixOS release from which the default
  # settings for stateful data, like file locations and database versions
  # on your system were taken. It‘s perfectly fine and recommended to leave
  # this value at the release version of the first install of this system.
  # Before changing this value read the documentation for this option
  # (e.g. man configuration.nix or on https://nixos.org/nixos/options.html).
  system.stateVersion = "24.05"; # Did you read the comment?

}
