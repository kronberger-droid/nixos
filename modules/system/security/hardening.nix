# Host-agnostic hardening: sshd policy, fail2ban, kernel sysctls, auditd and
# the sudo defaults. No firewall policy in here, since that is where hosts
# legitimately differ (workstations open SSH on tailscale0 only, the
# homeserver serves the LAN). Workstations get this through security.nix;
# the homeserver, which does not import common.nix, imports it directly.
# Before this split the homeserver carried a hand-copied version of every
# block below, without the mkDefaults, and had already drifted.
{
  pkgs,
  lib,
  username,
  ...
}: {
  services = {
    # Fail2ban for SSH protection.
    # mkDefault so hosts where SSH isn't reachable from the public internet
    # (e.g. spectre — SSH is only opened on tailscale0) can disable it.
    fail2ban = {
      enable = lib.mkDefault true;
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

    openssh = {
      enable = true;
      # Never open port 22 everywhere from here. Each host decides where SSH
      # is reachable: security.nix puts it on tailscale0, the homeserver
      # lists it for the LAN explicitly.
      openFirewall = false;
      settings = {
        PasswordAuthentication = false;
        PermitRootLogin = "no";

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

        # List option, so a host with extra accounts (homeserver: nix-remote,
        # wiesinger) appends to this rather than replacing it.
        AllowUsers = [username];

        # Algorithm allowlists. These have to live in `settings`, not
        # extraConfig: nixpkgs writes its own KexAlgorithms/Ciphers/Macs
        # lines into sshd_config before extraConfig, and sshd takes the
        # first occurrence of a keyword, so the extraConfig copies these
        # replace were never in effect. Through `settings` they replace
        # nixpkgs' defaults instead of trailing them.
        KexAlgorithms = [
          "mlkem768x25519-sha256"
          "sntrup761x25519-sha512"
          "curve25519-sha256"
          "curve25519-sha256@libssh.org"
          "diffie-hellman-group16-sha512"
          "diffie-hellman-group18-sha512"
        ];
        Ciphers = [
          "chacha20-poly1305@openssh.com"
          "aes256-gcm@openssh.com"
          "aes128-gcm@openssh.com"
          "aes256-ctr"
          "aes192-ctr"
          "aes128-ctr"
        ];
        Macs = [
          "hmac-sha2-256-etm@openssh.com"
          "hmac-sha2-512-etm@openssh.com"
          "umac-128-etm@openssh.com"
        ];
        HostKeyAlgorithms = "ssh-ed25519,ssh-ed25519-cert-v01@openssh.com,sk-ssh-ed25519@openssh.com,rsa-sha2-256,rsa-sha2-512";
        PubkeyAcceptedAlgorithms = "ssh-ed25519,ssh-ed25519-cert-v01@openssh.com,sk-ssh-ed25519@openssh.com,rsa-sha2-256,rsa-sha2-512";
      };
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

    # Virtual memory security. `vm.mmap_rnd_bits` (32) and
    # `vm.mmap_rnd_compat_bits` (16) are now set by nixpkgs in
    # `nixos/modules/config/sysctl.nix` with a unique-valued option type,
    # which rejects same-priority duplicates. Leave them to nixpkgs.
    "vm.mmap_min_addr" = lib.mkDefault 65536;

    # Reboot on kernel oops/panic to avoid unstable state
    "kernel.panic_on_oops" = lib.mkDefault 1;
    "kernel.panic" = lib.mkDefault 10;
  };

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
        # utmp/wtmp/btmp watches removed: those files are touched on every
        # login, logout, and `who`, generating constant audit records that
        # duplicate systemd-logind's own session journal.
      ];
    };

    # sudo-rs defaults (sudo-rs itself is enabled in core/users.nix on
    # workstations and directly in the homeserver's config)
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
