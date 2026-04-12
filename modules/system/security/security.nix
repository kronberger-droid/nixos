{pkgs, lib, ...}: {
  # Enhanced firewall configuration
  networking.firewall = {
    enable = true;
    allowPing = false;

    # SSH restricted to Tailscale interface only (see extraCommands below)
    allowedTCPPorts = [];

    # Allow specific applications through the firewall
    allowedTCPPortRanges = [
      # LocalSend port range
      {
        from = 53317;
        to = 53317;
      }
    ];

    # Block unnecessary protocols
    allowedUDPPorts = [];

    # Allow SSH only on Tailscale interface
    extraCommands = ''
      iptables -A INPUT -i tailscale0 -p tcp --dport 22 -j ACCEPT
      iptables -A INPUT -m limit --limit 5/min -j LOG --log-prefix "iptables denied: " --log-level 7
    '';
    extraStopCommands = ''
      iptables -D INPUT -i tailscale0 -p tcp --dport 22 -j ACCEPT || true
    '';
  };

  # Security services
  services = {
    # Fail2ban for SSH protection
    fail2ban = {
      enable = true;
      maxretry = 3;
      bantime = "1h";
      bantime-increment = {
        enable = true;
        maxtime = "168h"; # 1 week
        factor = "4";
      };

      jails = {
        ssh = {
          settings = {
            enabled = true;
            port = "ssh";
            filter = "sshd";
            backend = "systemd";
            maxretry = 3;
            findtime = "10m";
            bantime = "1h";
          };
        };
      };
    };

    # Enhanced SSH security
    openssh = {
      enable = true;
      settings = {
        # Disable password authentication
        PasswordAuthentication = false;
        PermitRootLogin = "no";

        # Protocol and cipher security
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
        AllowUsers = ["kronberger"];
      };

      # Use strong key exchange algorithms
      extraConfig = ''
        HostKeyAlgorithms ssh-ed25519,ssh-ed25519-cert-v01@openssh.com,sk-ssh-ed25519@openssh.com,rsa-sha2-256,rsa-sha2-512
        PubkeyAcceptedKeyTypes ssh-ed25519,ssh-ed25519-cert-v01@openssh.com,sk-ssh-ed25519@openssh.com,rsa-sha2-256,rsa-sha2-512
        KexAlgorithms curve25519-sha256@libssh.org,diffie-hellman-group16-sha512,diffie-hellman-group18-sha512
        Ciphers chacha20-poly1305@openssh.com,aes256-gcm@openssh.com,aes128-gcm@openssh.com,aes256-ctr,aes192-ctr,aes128-ctr
        MACs hmac-sha2-256-etm@openssh.com,hmac-sha2-512-etm@openssh.com,umac-128-etm@openssh.com
      '';
    };

    # Configure log rotation for audit logs
    logrotate = {
      enable = true;
      settings = {
        "/var/log/audit/audit.log" = {
          frequency = "weekly";
          rotate = 4;
          compress = true;
          delaycompress = true;
          missingok = true;
          notifempty = true;
          postrotate = "systemctl kill -s USR1 auditd.service || true";
        };
      };
    };
  };

  # Kernel security hardening (mkDefault so host-specific configs can override)
  boot.kernel.sysctl = {
    # Network security
    "net.ipv4.conf.all.send_redirects" = lib.mkDefault 0;
    "net.ipv4.conf.default.send_redirects" = lib.mkDefault 0;
    "net.ipv4.conf.all.accept_redirects" = lib.mkDefault 0;
    "net.ipv4.conf.default.accept_redirects" = lib.mkDefault 0;
    "net.ipv4.conf.all.secure_redirects" = lib.mkDefault 0;
    "net.ipv4.conf.default.secure_redirects" = lib.mkDefault 0;
    "net.ipv6.conf.all.accept_redirects" = lib.mkDefault 0;
    "net.ipv6.conf.default.accept_redirects" = lib.mkDefault 0;
    "net.ipv4.conf.all.accept_source_route" = lib.mkDefault 0;
    "net.ipv4.conf.default.accept_source_route" = lib.mkDefault 0;
    "net.ipv6.conf.all.accept_source_route" = lib.mkDefault 0;
    "net.ipv6.conf.default.accept_source_route" = lib.mkDefault 0;

    # IP spoofing protection
    "net.ipv4.conf.all.rp_filter" = lib.mkDefault 1;
    "net.ipv4.conf.default.rp_filter" = lib.mkDefault 1;

    # Ignore broadcast ping requests (keep unicast ICMP for path MTU discovery)
    "net.ipv4.icmp_echo_ignore_broadcasts" = lib.mkDefault 1;

    # Log Martians
    "net.ipv4.conf.all.log_martians" = lib.mkDefault 1;
    "net.ipv4.conf.default.log_martians" = lib.mkDefault 1;

    # TCP SYN flood protection
    "net.ipv4.tcp_syncookies" = lib.mkDefault 1;
    "net.ipv4.tcp_max_syn_backlog" = lib.mkDefault 2048;
    "net.ipv4.tcp_synack_retries" = lib.mkDefault 2;
    "net.ipv4.tcp_syn_retries" = lib.mkDefault 5;

    # Kernel security
    "kernel.dmesg_restrict" = lib.mkDefault 1;
    "kernel.kptr_restrict" = lib.mkForce 2; # nixpkgs defaults to 1, we want stricter
    "kernel.yama.ptrace_scope" = lib.mkDefault 1;
    "kernel.kexec_load_disabled" = lib.mkDefault 1;

    # Disable core dumps for security
    "fs.suid_dumpable" = lib.mkDefault 0;

    # Virtual memory security
    "vm.mmap_rnd_bits" = lib.mkDefault 32;
    "vm.mmap_rnd_compat_bits" = lib.mkDefault 16;
    "vm.mmap_min_addr" = lib.mkDefault 65536;

    # Reboot on kernel oops/panic to avoid unstable state
    "kernel.panic_on_oops" = lib.mkDefault 1;
    "kernel.panic" = lib.mkDefault 10;
  };

  # Additional security measures
  security = {
    # Audit system
    auditd.enable = true;
    audit = {
      enable = true;
      rules = [
        # Log all administrative actions
        "-w /etc/passwd -p wa -k identity"
        "-w /etc/group -p wa -k identity"
        "-w /etc/shadow -p wa -k identity"
        "-w /etc/sudoers -p wa -k identity"
        "-w /var/log/faillog -p wa -k logins"
        "-w /var/log/lastlog -p wa -k logins"
        "-w /var/log/tallylog -p wa -k logins"
        "-w /var/run/utmp -p wa -k session"
        "-w /var/log/wtmp -p wa -k logins"
        "-w /var/log/btmp -p wa -k logins"
      ];
    };

    # sudo-rs hardening (sudo-rs is enabled in users.nix)
    sudo-rs.extraConfig = ''
      Defaults timestamp_timeout=5
      Defaults passwd_timeout=1
      Defaults use_pty
    '';
  };

  # System monitoring and intrusion detection
  environment.systemPackages = with pkgs; [
    lynis
  ];
}
