{pkgs, lib, arrabbiata, inputs, ...}: {
  imports = [
    ./hardware-configuration.nix
    ../../modules/system/core/nix-settings.nix
    ../../modules/system/core/locale.nix
    ../../modules/system/services/arrabbiata.nix
    ../../modules/system/services/syncthing.nix
  ];

  # Secrets (homeserver-specific — shared agenix.nix has desktop-only secrets)
  age.secrets.miniflux-credentials = {
    file = "${inputs.self}/secrets/miniflux-credentials.age";
    path = "/run/secrets/miniflux-credentials";
    mode = "0400";
    owner = "root";
  };

  age.secrets.cache-private-key = {
    file = "${inputs.self}/secrets/cache-private-key.age";
    path = "/run/secrets/cache-private-key";
    mode = "0400";
  };

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

    firewall = {
      enable = true;
      allowPing = false;
      allowedTCPPorts = [22 53 3080 5001 8070];
      allowedUDPPorts = [53];

      # Log dropped packets (limited to prevent log spam)
      extraCommands = ''
        iptables -A INPUT -m limit --limit 5/min -j LOG --log-prefix "iptables denied: " --log-level 7
      '';
    };
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
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIGNMj1J9Y7Qc6oVzZQsAizZUJIP/F4bNn4hZmc4pCGeA kronberger@homeserver" # nothing phone (termux)
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
      PermitRootLogin = "no";
      PasswordAuthentication = false;
      KbdInteractiveAuthentication = false;
      PubkeyAuthentication = true;
      X11Forwarding = false;

      # Connection limits
      MaxAuthTries = 3;
      MaxSessions = 10;
      MaxStartups = "10:30:60";

      # Timeout settings
      ClientAliveInterval = 300;
      ClientAliveCountMax = 2;
      LoginGraceTime = 30;

      # Only allow specific users
      AllowUsers = ["kronberger" "wiesinger"];
    };

    # Strong ciphers and key exchange
    extraConfig = ''
      HostKeyAlgorithms ssh-ed25519,ssh-ed25519-cert-v01@openssh.com,sk-ssh-ed25519@openssh.com,rsa-sha2-256,rsa-sha2-512
      PubkeyAcceptedKeyTypes ssh-ed25519,ssh-ed25519-cert-v01@openssh.com,sk-ssh-ed25519@openssh.com,rsa-sha2-256,rsa-sha2-512
      KexAlgorithms curve25519-sha256@libssh.org,diffie-hellman-group16-sha512,diffie-hellman-group18-sha512
      Ciphers chacha20-poly1305@openssh.com,aes256-gcm@openssh.com,aes128-gcm@openssh.com,aes256-ctr,aes192-ctr,aes128-ctr
      MACs hmac-sha2-256-etm@openssh.com,hmac-sha2-512-etm@openssh.com,umac-128-etm@openssh.com
    '';
  };

  services.fail2ban = {
    enable = true;
    maxretry = 3;
    bantime = "1h";
    bantime-increment = {
      enable = true;
      maxtime = "168h"; # 1 week
      factor = "4";
    };
    jails.ssh.settings = {
      enabled = true;
      port = "ssh";
      filter = "sshd";
      backend = "systemd";
      maxretry = 3;
      findtime = "10m";
      bantime = "1h";
    };
  };

  services.tailscale.enable = true;

  # Binary cache — serves /nix/store to other machines on the network
  services.nix-serve = {
    enable = true;
    package = pkgs.nix-serve-ng;
    port = 5001;
    secretKeyFile = "/run/secrets/cache-private-key";
    # Priority > cache.nixos.org (40), so it's queried as a fallback rather
    # than first. Avoids stalling evals when the LAN cache serves a narinfo
    # but 404s the matching .nar.
    extraParams = "--priority 50";
  };

  # DNS + ad blocking — accessible on LAN (:53) and web UI (:3080)
  services.adguardhome = {
    enable = true;
    mutableSettings = false;
    port = 3080;
    settings = {
      dns = {
        bind_hosts = ["0.0.0.0"];
        port = 53;
        upstream_dns = [
          "https://dns.cloudflare.com/dns-query"
          "https://dns.google/dns-query"
        ];
        bootstrap_dns = ["1.1.1.1" "8.8.8.8"];
      };
      filtering.rewrites = [
        # Local DNS — add your services here
        {domain = "adguard.home.lan"; answer = "192.168.2.54"; enabled = true;}
        {domain = "rss.home.lan"; answer = "192.168.2.54"; enabled = true;}
      ];
    };
  };
  services.arrabbiata = {
    enable = true;
    package = arrabbiata;
  };

  # RSS reader — backed by PostgreSQL (auto-provisioned by the module)
  services.miniflux = {
    enable = true;
    config = {
      LISTEN_ADDR = "0.0.0.0:8070";
      BASE_URL = "http://rss.home.lan:8070";
      POLLING_FREQUENCY = "15";
      CLEANUP_ARCHIVE_UNREAD_DAYS = "-1";
      CLEANUP_ARCHIVE_READ_DAYS = "60";
    };
    adminCredentialsFile = "/run/secrets/miniflux-credentials";
  };

  # Power saving
  powerManagement.powertop.enable = true;
  services.thermald.enable = true;

  # sudo-rs hardening
  security.sudo-rs = {
    enable = true;
    extraRules = [{
      users = ["kronberger"];
      commands = [{
        command = "ALL";
        options = ["NOPASSWD"];
      }];
    }];
    extraConfig = ''
      Defaults timestamp_timeout=5
      Defaults passwd_timeout=1
      Defaults use_pty
    '';
  };

  # Kernel security hardening
  boot.kernel.sysctl = {
    # Network security
    "net.ipv4.conf.all.send_redirects" = 0;
    "net.ipv4.conf.default.send_redirects" = 0;
    "net.ipv4.conf.all.accept_redirects" = 0;
    "net.ipv4.conf.default.accept_redirects" = 0;
    "net.ipv4.conf.all.secure_redirects" = 0;
    "net.ipv4.conf.default.secure_redirects" = 0;
    "net.ipv6.conf.all.accept_redirects" = 0;
    "net.ipv6.conf.default.accept_redirects" = 0;
    "net.ipv4.conf.all.accept_source_route" = 0;
    "net.ipv4.conf.default.accept_source_route" = 0;
    "net.ipv6.conf.all.accept_source_route" = 0;
    "net.ipv6.conf.default.accept_source_route" = 0;

    # IP spoofing protection
    "net.ipv4.conf.all.rp_filter" = 1;
    "net.ipv4.conf.default.rp_filter" = 1;

    # Ignore broadcast ping
    "net.ipv4.icmp_echo_ignore_broadcasts" = 1;

    # TCP SYN flood protection
    "net.ipv4.tcp_syncookies" = 1;
    "net.ipv4.tcp_max_syn_backlog" = 2048;
    "net.ipv4.tcp_synack_retries" = 2;
    "net.ipv4.tcp_syn_retries" = 5;

    # Kernel security
    "kernel.dmesg_restrict" = 1;
    "kernel.kptr_restrict" = 2;
    "kernel.yama.ptrace_scope" = 1;
    "kernel.kexec_load_disabled" = 1;

    # Disable core dumps
    "fs.suid_dumpable" = 0;
  };

  # Override: don't list self as a remote builder
  nix.buildMachines = lib.mkForce [];

  # Limit build parallelism to avoid OOM
  nix.settings.max-jobs = 4;
  nix.settings.cores = 4;

  # Disable sleep — it's a server
  systemd.sleep.settings.Sleep = {
    AllowSuspend = "no";
    AllowHibernation = "no";
    AllowHybridSleep = "no";
    AllowSuspendThenHibernate = "no";
  };

  system.stateVersion = "25.11";
}
