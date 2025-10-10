{ pkgs, ... }:
{
  # Enhanced firewall configuration
  networking.firewall = {
    enable = true;
    allowPing = false;

    # Only allow essential services
    allowedTCPPorts = [ 22 ]; # SSH only by default

    # Allow specific applications through the firewall
    allowedTCPPortRanges = [
      # LocalSend port range
      { from = 53317; to = 53317; }
    ];

    # Block unnecessary protocols
    allowedUDPPorts = [ ];

    # Additional firewall rules for better security
    extraCommands = ''
      # Rate limiting for SSH
      iptables -A INPUT -p tcp --dport 22 -m conntrack --ctstate NEW -m recent --set --name ssh_attempts
      iptables -A INPUT -p tcp --dport 22 -m conntrack --ctstate NEW -m recent --update --seconds 60 --hitcount 4 --name ssh_attempts -j DROP

      # Log dropped packets (limited to prevent log spam)
      iptables -A INPUT -m limit --limit 5/min -j LOG --log-prefix "iptables denied: " --log-level 7

      # Block common attack patterns
      iptables -A INPUT -p tcp --tcp-flags ALL NONE -j DROP
      iptables -A INPUT -p tcp --tcp-flags ALL ALL -j DROP
      iptables -A INPUT -p tcp --tcp-flags ALL FIN,PSH,URG -j DROP
      iptables -A INPUT -p tcp --tcp-flags ALL SYN,RST,ACK,FIN,URG -j DROP
    '';

    extraStopCommands = ''
      iptables -D INPUT -p tcp --dport 22 -m conntrack --ctstate NEW -m recent --set --name ssh_attempts 2>/dev/null || true
      iptables -D INPUT -p tcp --dport 22 -m conntrack --ctstate NEW -m recent --update --seconds 60 --hitcount 4 --name ssh_attempts -j DROP 2>/dev/null || true
    '';
  };

  # Fail2ban for SSH protection
  services.fail2ban = {
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
          logpath = "/var/log/auth.log";
          maxretry = 3;
          findtime = "10m";
          bantime = "1h";
        };
      };
    };
  };

  # Enhanced SSH security
  services.openssh = {
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
      AllowUsers = [ "kronberger" ];
    };

    # Use strong key exchange algorithms
    extraConfig = ''
      Protocol 2
      HostKeyAlgorithms ssh-ed25519,ssh-ed25519-cert-v01@openssh.com,sk-ssh-ed25519@openssh.com,rsa-sha2-256,rsa-sha2-512
      PubkeyAcceptedKeyTypes ssh-ed25519,ssh-ed25519-cert-v01@openssh.com,sk-ssh-ed25519@openssh.com,rsa-sha2-256,rsa-sha2-512
      KexAlgorithms curve25519-sha256@libssh.org,diffie-hellman-group16-sha512,diffie-hellman-group18-sha512
      Ciphers chacha20-poly1305@openssh.com,aes256-gcm@openssh.com,aes128-gcm@openssh.com,aes256-ctr,aes192-ctr,aes128-ctr
      MACs hmac-sha2-256-etm@openssh.com,hmac-sha2-512-etm@openssh.com,umac-128-etm@openssh.com
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

    # Ignore ICMP ping requests
    "net.ipv4.icmp_echo_ignore_all" = 1;
    "net.ipv6.icmp.echo_ignore_all" = 1;

    # Ignore broadcast ping requests
    "net.ipv4.icmp_echo_ignore_broadcasts" = 1;

    # Log Martians
    "net.ipv4.conf.all.log_martians" = 1;
    "net.ipv4.conf.default.log_martians" = 1;

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

    # Disable core dumps for security
    "fs.suid_dumpable" = 0;

    # Virtual memory security
    "vm.mmap_rnd_bits" = 32;
    "vm.mmap_rnd_compat_bits" = 16;
  };

  # Additional security measures
  security = {
    # Prevent users from mounting filesystems
    wrappers = {
      # Ensure sudo wrapper has correct permissions
      sudo.setuid = true;
    };

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
  };

  # Enhanced sudo security
  security.sudo = {
    extraConfig = ''
      # Require password for every sudo command
      Defaults timestamp_timeout=0
      Defaults passwd_timeout=1
      Defaults logfile="/var/log/sudo.log"
      Defaults log_input,log_output
      Defaults iolog_dir="/var/log/sudo-io"
      Defaults requiretty
      Defaults use_pty
    '';
  };

  # System monitoring and intrusion detection
  environment.systemPackages = with pkgs; [
    lynis
  ];
}