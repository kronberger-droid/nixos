{
  pkgs,
  lib,
  inputs,
  username,
  ...
}: {
  imports = [
    ./hardware-configuration.nix
    ../../modules/system/core/nix-settings.nix
    ../../modules/system/core/activation.nix
    ../../modules/system/core/locale.nix
    ../../modules/system/core/esp-permissions.nix
    ../../modules/system/security/hardening.nix
    ../../modules/system/services/syncthing.nix
    ../../modules/system/services/website.nix
    ../../modules/system/services/webdav.nix
    ../../modules/system/services/dns-healthcheck.nix
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

  # Cloudflare Tunnel credentials JSON. Stays root-owned: the cloudflared unit
  # runs under DynamicUser but pulls this in via systemd LoadCredential, which
  # reads it as root before dropping privileges.
  age.secrets.cloudflared-website = {
    file = "${inputs.self}/secrets/cloudflared-website.age";
    path = "/run/secrets/cloudflared-website";
    mode = "0400";
    owner = "root";
  };

  # Radicale htpasswd line (`user:$2y$...`), read by the radicale service user.
  age.secrets.radicale-htpasswd = {
    file = "${inputs.self}/secrets/radicale-htpasswd.age";
    path = "/run/secrets/radicale-htpasswd";
    mode = "0400";
    owner = "radicale";
  };

  # ZOTERO_DAV_USER / ZOTERO_DAV_PASSWORD, in systemd EnvironmentFile form.
  # Stays root-owned: systemd reads it as root before dropping to the webdav
  # user (see the comment in services/webdav.nix).
  age.secrets.webdav-zotero = {
    file = "${inputs.self}/secrets/webdav-zotero.age";
    path = "/run/secrets/webdav-zotero";
    mode = "0400";
    owner = "root";
  };

  # Bootloader. Set directly rather than via boot-systemd.nix, so the two
  # defaults that module would give us are spelled out here: no boot-time
  # cmdline editor (init=/bin/sh at the menu is root), and a generation cap
  # so the ESP does not fill up between weekly GCs.
  boot.loader.systemd-boot = {
    enable = true;
    editor = false;
    configurationLimit = 20;
  };
  boot.loader.efi.canTouchEfiVariables = true;

  # The generated hardware config ties Intel microcode updates to this flag
  # (`updateMicrocode = mkDefault enableRedistributableFirmware`), and only
  # the laptop profile set it, so the always-on box ran stock BIOS
  # microcode with none of the errata or side-channel fixes.
  hardware.enableRedistributableFirmware = true;

  # aarch64 emulation so this host can act as remote builder for the phone's
  # nix-on-droid config (proot on the phone cannot allocate build ptys, so the
  # droid config points its `builders` here and never builds locally).
  boot.binfmt.emulatedSystems = ["aarch64-linux"];

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
    # This host runs the LAN's resolver, so it resolves through itself.
    # 8.8.8.8 on UDP/53 was never reachable here: the ISP blocks outbound
    # UDP/53 to every destination (see hosts/edgerouter/README.md), which is
    # why AdGuard's upstreams are IP-literal DoH. With Google listed first
    # every local lookup depended on Tailscale's DNS proxy answering.
    nameservers = ["127.0.0.1"];

    firewall = {
      enable = true;
      # ICMP is the only liveness check the network has for the one host
      # everything depends on.
      allowPing = true;
      # LAN-wide: SSH, DNS, and syncthing (22000/21027, appended by
      # modules/system/services/syncthing.nix). Everything else on this box
      # speaks plain HTTP (Radicale is Basic auth, immich and miniflux are
      # password logins, harmonia serves the store) and is only meant to be
      # reached over the tailnet, so it is opened on tailscale0 alone, the
      # same way modules/system/services/webdav.nix scopes port 8081.
      # Tailscale's subnet route still lets tailnet peers reach the LAN, not
      # the reverse. Two things this list does not govern: docker's own
      # DOCKER chains sit ahead of nixos-fw, so any container port published
      # with -p is LAN-reachable regardless; and `flake --remote` depends on
      # the tailnet end to end (ssh via MagicDNS, the cache on 5001).
      allowedTCPPorts = [22 53];
      allowedUDPPorts = [53];
      interfaces."tailscale0".allowedTCPPorts = [
        3080 # AdGuard admin UI
        5001 # harmonia binary cache
        8070 # miniflux
        2283 # immich
        5232 # radicale
      ];

      # Rate-limited log of dropped packets. This is the module default and
      # is spelled out because the hand-rolled iptables LOG line it replaces
      # did the same job on top of it, without a matching stop command, so it
      # stacked a duplicate on every firewall reload.
      logRefusedConnections = true;
    };
  };

  # Users
  #
  # ${username} has NOPASSWD sudo (below) because deploy-rs logs in as this
  # account and escalates to activate the profile, so only the workstation
  # keys reach it. Anything that just needs a Nix store on the far side
  # (remote builds, `flake --remote`, the phone's builder) goes through
  # `nix-remote` instead.
  #
  # Be clear about what that buys: `nix-remote` is a trusted Nix user, and a
  # trusted user can hand the daemon settings like post-build-hook, which is
  # root by a slower route. The split keeps the phone and the builder key
  # away from an account with an interactive shell and sudo, and it keeps
  # the two purposes reviewable, but every key on `nix-remote` is still a
  # key you would give root on this box. Unsigned uploads (what
  # `nix flake archive --to ssh-ng://` and remote builds do) need trusted;
  # the alternative is signing paths on every client, which is a bigger
  # change than this config has wanted so far.
  users.users.${username} = {
    createHome = true;
    isNormalUser = true;
    extraGroups = ["wheel"];
    shell = pkgs.nushell;
    openssh.authorizedKeys.keys = builtins.attrValues (import ../../modules/shared/ssh-keys.nix);
  };

  # Builder account: `nix flake archive --to ssh-ng://nix-remote@homeserver`
  # and `nix build` under this user, plus the dormant buildMachines entry and
  # the phone's `builders`. Uploading unsigned paths needs trusted-user;
  # nothing here needs wheel, sudo, or a login shell beyond running nix.
  # Normal user rather than system user so it gets a home for nix's own
  # caches and for the gcroots `flake --remote` leaves under ~/.local/state.
  users.users.nix-remote = {
    isNormalUser = true;
    createHome = true;
    shell = pkgs.bash;
    openssh.authorizedKeys.keys =
      builtins.attrValues (import ../../modules/shared/ssh-keys.nix)
      ++ [
        # spectre's root key, for the buildMachines entry (nix-daemon runs
        # the builder connection as root).
        "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIBhJDPNrVbt//EeQVXT4stPOH+gFCjrYKHrrAvqbUKBE root@spectre"
        # Nothing Phone (Termux). Only ever needs the store, so it is not in
        # the shared key set any more; key was generated on the homeserver,
        # hence the comment.
        "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIGNMj1J9Y7Qc6oVzZQsAizZUJIP/F4bNn4hZmc4pCGeA kronberger@homeserver"
      ];
  };
  # Trusted users are always allowed to connect to the daemon, whatever
  # allowed-users says, so this one line is the whole grant.
  nix.settings.trusted-users = ["nix-remote"];

  # Container deployments. `docker` alone is still root-equivalent through
  # the socket; moving these workloads to rootless podman is the real fix
  # and is tracked in the vault's config review. wheel was on top of that
  # and served nothing.
  users.users.wiesinger = {
    isNormalUser = true;
    createHome = true;
    extraGroups = ["docker"];
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
    zellij
    docker-compose
    lm_sensors
    # Claude Code, from the sadjow/claude-code-nix flake input rather than
    # nixpkgs — same build every other host gets, and nix-caches.nix already
    # trusts claude-code.cachix.org so it comes down prebuilt.
    claude-code-bin
    # Rust toolchain for building/testing crates (e.g. the nushell fork)
    # directly on the server. nixpkgs' cargo/rustc — matches the compiler
    # nixpkgs' own nushell build uses. gcc + pkg-config + openssl cover the
    # usual native link/build deps a `cargo build` needs.
    cargo
    rustc
    gcc
    pkg-config
    openssl
  ];

  # Docker — for wiesinger to deploy containers without touching Nix
  virtualisation.docker = {
    enable = true;
    autoPrune = {
      enable = true;
      dates = "weekly";
      # Bare `docker system prune -f` removes every stopped container and
      # dangling image on the spot, so anything that happened to be stopped
      # when the timer fired was gone. Only prune what has been unused for
      # a week.
      flags = ["--filter" "until=168h"];
    };
  };

  # Services
  # sshd policy, fail2ban, sysctls, auditd and sudo defaults all come from
  # modules/system/security/hardening.nix (imported above). Only the
  # host-specific additions live here: the extra accounts sshd may admit.
  # ${username} is already in the list from the shared module.
  services.openssh.settings.AllowUsers = ["nix-remote" "wiesinger"];

  # Subnet router for the LAN. Advertising 192.168.2.0/24 lets every tailnet
  # device reach hardware that will never run Tailscale itself: the EdgeRouter
  # at .1, the AP at .38, and the Bambu printer at .39, whose MQTT, FTPS and
  # camera ports are LAN-only by design once cloud mode is off. So the printer
  # keeps its prints off Bambu's servers and stays reachable from a phone.
  #
  # Without this, administering the network requires being physically on it.
  # That gap showed up concretely while debugging the DNS outage: homeserver
  # stayed reachable over the tailnet the whole time, but the router did not,
  # so the one box that needed looking at was the one box unreachable.
  #
  # Two manual steps this cannot express. The route needs approving once in the
  # admin console, and Linux peers need `--accept-routes` to use it (iOS and
  # Android accept advertised routes automatically).
  services.tailscale = {
    enable = true;

    # Sets net.ipv4.conf.all.forwarding and the v6 equivalent, which is all a
    # subnet router needs. It deliberately leaves reverse-path filtering strict:
    # nixpkgs only loosens that for "client"/"both", since neither direction
    # here is asymmetric. Inbound arrives on tailscale0 from 100.x and replies
    # leave the same way, while LAN replies arrive on enp86s0 from a prefix
    # routed back out enp86s0. If routing ever misbehaves, that is the knob.
    useRoutingFeatures = "server";

    # `tailscale set` rather than `tailscale up`, since extraUpFlags only
    # applies when a node authenticates from an authKeyFile and this one is
    # already enrolled. `set` reconfigures a running node in place.
    extraSetFlags = ["--advertise-routes=192.168.2.0/24"];
  };

  # Binary cache — serves /nix/store to other machines on the network. Same
  # port and signing key as the nix-serve it replaced, so the substituter and
  # trusted-public-keys in modules/system/core/nix-caches.nix are unchanged.
  #
  # The upstream module runs under DynamicUser, which is what bit nix-serve
  # here (its getpwuid() raced nsncd at boot and tripped deploy-rs's
  # rollback). Harmonia dodges that on two counts: the signing key comes in
  # via LoadCredential, read as root before privileges drop, and the unit is
  # socket-activated, so activation only starts the listener and the service
  # itself forks on the first request, long after nsncd is answering.
  services.harmonia.cache = {
    enable = true;
    signKeyPaths = ["/run/secrets/cache-private-key"];
    settings = {
      bind = "[::]:5001";
      # Priority > cache.nixos.org (40), so it's queried as a fallback rather
      # than first. Avoids stalling evals when the LAN cache serves a narinfo
      # but 404s the matching .nar.
      priority = 50;
    };
  };

  # DNS + ad blocking — :53 on the LAN, web UI (:3080) on the tailnet only.
  services.adguardhome = {
    enable = true;
    mutableSettings = false;
    port = 3080;
    settings = {
      # mutableSettings = false means the module copies this YAML over the
      # state file on every start, so an admin user set through the UI was
      # wiped on the next restart (including the ones dns-healthcheck
      # triggers) and the UI, which can rewrite DNS for the whole LAN, ran
      # with no login at all. The bcrypt hash lives here in plain sight on
      # purpose: settings are evaluated at build time, so an agenix file
      # cannot feed it, and a hash for a tailnet-only LAN admin page is an
      # acceptable thing to commit. The password itself is in Bitwarden.
      users = [
        {
          name = "kronberger";
          password = "$2y$10$E49TmMek9cObE1k2Y191a.nDMDOGO41g0u1fR/r/f0bT8dNrdDWPW";
        }
      ];
      dns = {
        bind_hosts = ["0.0.0.0"];
        port = 53;
        # IP-literal DoH endpoints on purpose. The ISP blocks outbound UDP/53
        # entirely (every destination, including their own resolver), so a
        # hostname upstream like https://dns.cloudflare.com/dns-query can never
        # resolve its own bootstrap and AdGuard then answers nothing at all,
        # not even on loopback. Bare IPs need no bootstrap, and DoH rides
        # TCP/443, which the block does not touch. Google is deliberately
        # absent: https://8.8.8.8/dns-query serves HTML without the dns.google
        # SNI, so it is unusable as an IP literal. Cloudflare and Quad9 both
        # answer correctly on their bare addresses.
        upstream_dns = [
          "https://1.1.1.1/dns-query"
          "https://1.0.0.1/dns-query"
          "https://9.9.9.9/dns-query"
          "https://149.112.112.112/dns-query"
        ];
        # Unused now that no upstream carries a hostname, but AdGuard wants a
        # value. Keep it non-empty so adding a hostname upstream later fails
        # loudly rather than silently.
        bootstrap_dns = ["1.1.1.1" "9.9.9.9"];
      };
      filtering.rewrites = [
        # Local names for the services on this box. They answer with the
        # tailnet address, not the LAN one: the ports behind them (3080,
        # 8070, 2283) are opened on tailscale0 only, so a LAN answer would
        # resolve and then hang on a dropped SYN. A client without Tailscale
        # cannot reach these services either way.
        {
          domain = "adguard.home.lan";
          answer = "100.92.46.97";
          enabled = true;
        }
        {
          domain = "rss.home.lan";
          answer = "100.92.46.97";
          enabled = true;
        }
        {
          domain = "photos.home.lan";
          answer = "100.92.46.97";
          enabled = true;
        }
      ];
    };
  };
  # CardDAV/CalDAV server — contacts sync to the phone (DAVx5 -> stock Contacts)
  # and desktop (vdirsyncer/khard -> aerc). Reached over the tailnet at
  # http://homeserver:5232, already WireGuard-encrypted, so plain HTTP is fine.
  # Collections are stored as individual vCard files under the storage folder.
  services.radicale = {
    enable = true;
    settings = {
      server.hosts = ["0.0.0.0:5232" "[::]:5232"];
      auth = {
        type = "htpasswd";
        htpasswd_filename = "/run/secrets/radicale-htpasswd";
        # bcrypt line from `htpasswd -nbB`. If this radicale build lacks bcrypt
        # support, switch this to "plain"/"md5" and regenerate the secret.
        htpasswd_encryption = "bcrypt";
      };
      storage.filesystem_folder = "/var/lib/radicale/collections";
    };
  };
  # The radicale module sets no Restart=, unlike every other service on this
  # box, so one crash took contacts and calendar sync offline until someone
  # noticed DAVx5 failing on the phone.
  systemd.services.radicale.serviceConfig = {
    Restart = "on-failure";
    RestartSec = 5;
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

  # Photo/video backup — Postgres (vectorchord) + Redis auto-provisioned by the module.
  # Local unix-socket DB auth needs no secrets file (User=immich peers with role "immich").
  services.immich = {
    enable = true;
    host = "0.0.0.0";
    # ML worker (faces/smart search) is CPU-only inference, on-demand not continuous —
    # trim to machine-learning.enable = false if it strains the NUC's resources.
    machine-learning.enable = true;
  };

  # No powertop here. The option runs `powertop --auto-tune` at boot, which
  # turns on USB autosuspend, SATA/PCIe link power management and NIC
  # runtime PM: the wrong trade for a 24/7 box serving DNS and the cache,
  # and the same reason power-management.nix disables it on the laptops.

  # locale.nix (imported above) turns the full documentation set on for the
  # workstations. Headless box: man pages stay for `man` over ssh, the doc
  # and info trees do not earn their closure.
  documentation = {
    doc.enable = false;
    info.enable = false;
  };

  # sudo-rs hardening
  security.sudo-rs = {
    enable = true;
    # deploy-rs logs in as ${username} and escalates through this rule to
    # activate the profile; magic rollback confirms through the same path.
    # The Defaults (timeouts, use_pty) come from hardening.nix.
    extraRules = [
      {
        users = [username];
        commands = [
          {
            command = "ALL";
            options = ["NOPASSWD"];
          }
        ];
      }
    ];
  };

  # Override: don't list self as a remote builder
  nix.buildMachines = lib.mkForce [];

  # Limit build parallelism to avoid OOM
  nix.settings.max-jobs = 4;
  nix.settings.cores = 4;

  # Ops baseline the workstations get from hardware/performance.nix and
  # core/systemd-tweaks.nix via common.nix, which this host does not import.
  # The always-on box with the only copy of the photo library and the DNS
  # resolver had none of it.
  services.fstrim.enable = true;
  # SMART self-monitoring on the single NVMe. Default notifications go to the
  # journal and wall; there is no MTA here, so nothing more to wire up yet.
  services.smartd.enable = true;
  # 15 GB shared by Postgres, immich's ML worker, docker and remote builds.
  # earlyoom picks the largest process before the kernel OOM killer takes
  # Postgres. No notifications: there is no desktop session to show them.
  services.earlyoom = {
    enable = true;
    freeMemThreshold = 5;
    freeSwapThreshold = 5;
  };
  systemd.oomd.enable = false;
  zramSwap = {
    enable = true;
    algorithm = "zstd";
    memoryPercent = 25;
    priority = 10;
  };
  # immich's ML worker loads models on demand and has no ceiling by default.
  # Cap it well below RAM so a model load under build pressure gets the
  # worker restarted (Restart=on-failure from the module) rather than the
  # database killed.
  systemd.services.immich-machine-learning.serviceConfig.MemoryMax = "6G";
  # The firewall logs every dropped packet on the LAN-facing box, so without
  # a cap the journal grows to journald's default 10 % of /var on the same
  # disk as the photos.
  services.journald.settings.Journal = {
    Storage = "persistent";
    Compress = "yes";
    SystemMaxUse = "1G";
    RuntimeMaxUse = "100M";
  };

  # nix-settings.nix keeps outputs and derivations alive fleet-wide for the
  # dev shells. Here that would pin every build-time input of every client
  # generation that `flake --remote` roots under nix-remote's state dir
  # (compilers, sources, cargo vendor trees) on the same disk as the photo
  # library. Keep the .drv closures (cheap, useful for `nix log`), drop the
  # outputs.
  nix.settings.keep-outputs = lib.mkForce false;

  # Disable sleep — it's a server
  systemd.sleep.settings.Sleep = {
    AllowSuspend = "no";
    AllowHibernation = "no";
    AllowHybridSleep = "no";
    AllowSuspendThenHibernate = "no";
  };

  system.stateVersion = "25.11";
}
