{pkgs, ...}: {
  imports = [
    ./hardware-configuration.nix
    ../../modules/system/services/arrabbiata.nix
  ];

  # Bootloader
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  # Networking
  networking = {
    hostName = "homeserver";
    networkmanager.enable = false;
    useDHCP = false;
    interfaces.enp86s0.ipv4.addresses = [
      {
        address = "192.168.2.54";
        prefixLength = 24;
      }
    ];
    defaultGateway = "192.168.2.1";
    nameservers = ["8.8.8.8" "1.1.1.1"];
    firewall.allowedTCPPorts = [22 9443];
  };

  # Users
  users.users.kronberger = {
    createHome = true;
    isNormalUser = true;
    extraGroups = ["wheel"];
    shell = pkgs.nushell;
    openssh.authorizedKeys.keys = [
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAINEy1NxD4g5ZjbOG40mE3GUAlWFxBEJ+dtFrjNW9C2WR kronberger@devpi"
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIFijJelcEDGPlu9aDnjkLa4TWNXXJGeyHgw6ucANynAW"
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIFFXI1vd+dtthymv9vLy9QuoyGHuX5ZEkDXXSPfP6NVr"
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIBhJDPNrVbt//EeQVXT4stPOH+gFCjrYKHrrAvqbUKBE root@spectre" # nix remote builder
    ];
  };

  users.users.wiesinger = {
    isNormalUser = true;
    createHome = true;
    extraGroups = ["wheel" "docker"];
    openssh.authorizedKeys.keys = [
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIDkdsU9B7+sb5ISQy9RjykK0u04VdYTFYhnSHozpBqYl dietpi"
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIDZDyijah9B71tRnhZtLxLFuxJ9raP3RdwMSYihxECfA dietpi"
    ];
  };

  # Packages
  environment.systemPackages = with pkgs; [
    helix
    wget
    git
    nushell
    docker-compose
  ];

  # Docker — for wiesinger to deploy containers without touching Nix
  virtualisation.docker = {
    enable = true;
    autoPrune = {
      enable = true;
      dates = "weekly";
    };
  };

  # Services
  services.openssh = {
    enable = true;
    settings = {
      PermitRootLogin = "prohibit-password";
      PasswordAuthentication = false;
      KbdInteractiveAuthentication = false;
    };
  };

  services.fail2ban.enable = true;
  services.tailscale.enable = true;
  services.arrabbiata.enable = true;

  # Power saving
  powerManagement.powertop.enable = true;
  services.thermald.enable = true;

  # Nix settings
  nix.settings = {
    experimental-features = ["nix-command" "flakes"];
    trusted-users = ["root" "kronberger"];
  };

  # Disable sleep — it's a server
  systemd.sleep.settings.Sleep = {
    AllowSuspend = "no";
    AllowHibernation = "no";
    AllowHybridSleep = "no";
    AllowSuspendThenHibernate = "no";
  };

  system.stateVersion = "25.11";
}
