{
  config,
  pkgs,
  lib,
  inputs,
  username,
  ...
}: let
  hostKeys = import ../../modules/shared/host-keys.nix;
  addrs = import ../../modules/shared/homeserver.nix;
  # Keys that only ever talk to the store get no shell: the protocol command
  # is forced, as nix.sshServe does it. The personal keys stay unrestricted,
  # since `flake --remote` runs `nix build` over a plain ssh session.
  # from= keeps them to the tailnet (v4 CGNAT range and v6 ULA) and the LAN,
  # where every one of those clients lives.
  storeOnly = command: key: ''restrict,from="100.64.0.0/10,fd7a:115c:a1e0::/48,${addrs.lanSubnet}",command="${config.nix.package.out}/bin/${command}" ${key}'';
in {
  imports = [
    ./hardware-configuration.nix
    ../../modules/system/boot/boot-systemd.nix
    ../../modules/system/core/nix-settings.nix
    ../../modules/system/core/activation.nix
    ../../modules/system/core/locale.nix
    ../../modules/system/core/esp-permissions.nix
    ../../modules/system/security/hardening.nix
    ../../modules/system/security/agent-sandbox.nix
    ../../modules/system/services/syncthing.nix
    ../../modules/system/services/website.nix
    ../../modules/system/services/webdav.nix
    ../../modules/system/services/dns-healthcheck.nix
    ../../modules/system/services/flake-autoupdate.nix
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

  # The Claude Code sandbox's GitHub token, this host's own (see
  # secrets/secrets.nix). Root-only: the claude-remote-control unit gets it
  # through LoadCredential and exposes it under /run/claude-sandbox only
  # while a `claude-sandbox-open` window lasts (agent-sandbox.nix). Gated on
  # the file like the workstation one in agenix.nix, so the config evaluates
  # before the token is minted.
  age.secrets.claude-github-token = lib.mkIf (builtins.pathExists "${inputs.self}/secrets/claude-github-token-homeserver.age") {
    file = "${inputs.self}/secrets/claude-github-token-homeserver.age";
    path = "/run/secrets/claude-github-token";
    mode = "0400";
    owner = "root";
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

  # Bootloader: boot-systemd.nix's defaults, among them no boot-time cmdline
  # editor (init=/bin/sh at the menu is root) and a generation cap so the
  # ESP does not fill up between weekly GCs.
  boot.systemd-boot-defaults.enable = true;
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
        address = addrs.lan4;
        prefixLength = 24;
      }
    ];
    defaultGateway = "192.168.2.1";
    # This host runs the LAN's resolver, so it resolves through itself.
    # 8.8.8.8 on UDP/53 was never reachable here: the ISP blocks outbound
    # UDP/53 to every destination (see hosts/edgerouter/README.md), which is
    # why blocky's upstreams are IP-literal DoH. With Google listed first
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
      # the reverse. This list does not govern docker: a port published with
      # -p is DNAT'd to the container and forwarded, never reaching nixos-fw.
      # DOCKER-USER in extraCommands below scopes those to the tailnet. Also
      # `flake --remote` depends on the tailnet end to end (ssh via
      # MagicDNS, the cache on 5001).
      allowedTCPPorts = [22 53];
      allowedUDPPorts = [53];
      interfaces."tailscale0".allowedTCPPorts = [
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

      # Published container ports, tailnet only. DOCKER-USER is the chain
      # docker jumps to from FORWARD ahead of its own rules and never
      # rewrites, so this holds whatever a compose file publishes, including
      # an explicit 0.0.0.0. Matching on the inbound interface rather than
      # ports, since after DNAT the port is the container's (Open WebUI's
      # 3000 is 8080 there). The bridges stay open so containers reach each
      # other and the internet. Flushed, not deleted, on stop: docker keeps
      # its FORWARD jump into the chain.
      extraCommands = ''
        ip46tables -N DOCKER-USER 2>/dev/null || true
        ip46tables -F DOCKER-USER
        ip46tables -A DOCKER-USER -m conntrack --ctstate RELATED,ESTABLISHED -j RETURN
        ip46tables -A DOCKER-USER -i tailscale0 -j RETURN
        ip46tables -A DOCKER-USER -i docker0 -j RETURN
        ip46tables -A DOCKER-USER -i br-+ -j RETURN
        ip46tables -A DOCKER-USER -j DROP
      '';
      extraStopCommands = ''
        ip46tables -F DOCKER-USER 2>/dev/null || true
      '';
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
    # bash as the login shell, so `ssh homeserver <cmd>` and scripts piped
    # over ssh get POSIX sh. Interactive logins hop into nu below.
    shell = pkgs.bash;
    openssh.authorizedKeys.keys = builtins.attrValues (import ../../modules/shared/ssh-keys.nix);
  };
  # Only interactive login shells: a plain `bash` started from nu stays bash,
  # and root's `sudo -i` and the other accounts are left alone.
  programs.bash.interactiveShellInit = ''
    if shopt -q login_shell && [[ $(id -un) == ${username} ]]; then
      exec ${pkgs.nushell}/bin/nu --login
    fi
  '';

  # Builder account: `nix flake archive --to ssh-ng://nix-remote@homeserver`
  # and `nix build` under this user, plus the workstations' buildMachines
  # entry and the phone's `builders`. Uploading unsigned paths needs trusted-user;
  # nothing here needs wheel, sudo, or a login shell beyond running nix.
  # Normal user rather than system user so it gets a home for nix's own
  # caches and for the gcroots `flake --remote` leaves under ~/.local/state.
  users.users.nix-remote = {
    isNormalUser = true;
    createHome = true;
    shell = pkgs.bash;
    openssh.authorizedKeys.keys =
      builtins.attrValues (import ../../modules/shared/ssh-keys.nix)
      # The workstations' host keys, for the buildMachines entry: their
      # nix-daemon connects as root with /etc/ssh/ssh_host_ed25519_key, over
      # ssh-ng, i.e. `nix-daemon --stdio` on this side.
      ++ map (storeOnly "nix-daemon --stdio") [hostKeys.intelNuc hostKeys.spectre hostKeys.P14E]
      # Nothing Phone (Termux). Only ever needs the store, so it is not in the
      # shared key set any more; key was generated on the homeserver, hence
      # the comment. Its `builders` use the legacy ssh:// store, which runs
      # `nix-store --serve --write` here.
      ++ [(storeOnly "nix-store --serve --write" "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIGNMj1J9Y7Qc6oVzZQsAizZUJIP/F4bNn4hZmc4pCGeA kronberger@homeserver")];
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
    # No keys and not in AllowUsers: the DietPi box that deployed from was
    # retired. The account stays for the containers it owns.
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
    # Published ports are reached through DNAT instead of a root-owned
    # docker-proxy. With the proxy, the sandbox's connections to
    # 127.0.0.1:<port> leave through lo and docker-proxy relays them, so the
    # claude-sandbox-out REJECT on docker0/br-+ never sees them. Through
    # DNAT the packet is rerouted out the bridge before filter OUTPUT.
    daemon.settings.userland-proxy = false;
  };

  # Services
  # sshd policy, fail2ban, sysctls, auditd and sudo defaults all come from
  # modules/system/security/hardening.nix (imported above). Only the
  # host-specific additions live here: the extra accounts sshd may admit.
  # ${username} is already in the list from the shared module.
  services.openssh.settings.AllowUsers = ["nix-remote"];

  # The Claude Code sandbox, the same account the workstations have. It is
  # deliberately not in AllowUsers above: the way in is `ssh -t homeserver
  # claude-sandbox`, or a session spawned from claude.ai through Remote
  # Control, which runs only inside a window opened from any machine with
  # `ssh homeserver claude-sandbox-open 3h` (default 2h, at most 12h) and
  # ended early with `claude-sandbox-close`. Only shells started inside a
  # window get the GitHub token. Its
  # network reach matches intelNuc's sandbox (LAN and tailnet, no egress
  # filter), plus an admin login on the EdgeRouter that is set up by hand
  # on the router.
  security.agentSandbox = {
    enable = true;
    remoteControl.enable = true;
    # Off the docker bridges. DOCKER-USER above only sees forwarded traffic,
    # so a process on this host reaches every container directly, and
    # wiesinger's (a redis with no password among them) are not the agent's
    # business. By interface rather than subnet, so a new compose network
    # is covered too.
    egressRules = ''
      ip46tables -A claude-sandbox-out -o docker0 -j REJECT
      ip46tables -A claude-sandbox-out -o br-+ -j REJECT
    '';
  };

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
    extraSetFlags = ["--advertise-routes=${addrs.lanSubnet}"];
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

  # DNS + ad blocking for the LAN, on :53. Blocky rather than AdGuard Home:
  # the whole config is here and nowhere else, and there is no admin UI, so
  # no password to keep out of this public repo. No `ports.http` on purpose:
  # that would bring up blocky's REST API, whose /blocking/disable takes no
  # authentication.
  services.blocky = {
    enable = true;
    settings = {
      ports.dns = 53;

      upstreams = {
        # IP-literal DoH endpoints on purpose. The ISP blocks outbound UDP/53
        # entirely (every destination, including their own resolver), so a
        # hostname upstream like https://dns.cloudflare.com/dns-query could
        # never resolve itself, and the resolver would answer nothing at all,
        # not even on loopback. Bare IPs need no bootstrap, and DoH rides
        # TCP/443, which the block does not touch. Google is deliberately
        # absent: https://8.8.8.8/dns-query serves HTML without the dns.google
        # SNI, so it is unusable as an IP literal. Cloudflare and Quad9 both
        # answer correctly on their bare addresses.
        groups.default = [
          "https://1.1.1.1/dns-query"
          "https://1.0.0.1/dns-query"
          "https://9.9.9.9/dns-query"
          "https://149.112.112.112/dns-query"
        ];
        # Serve right away and keep retrying, rather than refusing to start
        # while the uplink is down. dns-healthcheck tells the two apart.
        init.strategy = "fast";
      };

      # What blocky resolves its own lookups with, the list downloads among
      # them. The default is the system resolver, which on this host is
      # blocky itself, and plain DNS anywhere else is blocked. So the same
      # IP-literal DoH as the upstreams.
      bootstrapDns = [
        {upstream = "https://1.1.1.1/dns-query";}
        {upstream = "https://9.9.9.9/dns-query";}
      ];

      # Local names for the services on this box. They answer with the
      # tailnet address, not the LAN one: the ports behind them (8070, 2283)
      # are opened on tailscale0 only, so a LAN answer would resolve and then
      # hang on a dropped SYN. A client without Tailscale cannot reach these
      # services either way.
      customDNS.mapping = {
        "rss.home.lan" = addrs.tailnet4;
        "photos.home.lan" = addrs.tailnet4;
      };

      blocking = {
        # HaGeZi Multi NORMAL, the usual stand-in for the AdGuard DNS filter
        # that AdGuard ran here (about 160k entries against its 185k).
        # Blocky reads no adblock syntax, so that list itself is out; the
        # wildcard build of this one blocks each domain with its subdomains,
        # the way `||domain^` did.
        denylists.ads = [
          "https://raw.githubusercontent.com/hagezi/dns-blocklists/main/wildcard/multi.txt"
        ];
        # Lists only apply to clients mapped to a group.
        clientGroupsBlock.default = ["ads"];
        loading = {
          refreshPeriod = "24h";
          # Start answering before the list is in; a failed download leaves
          # DNS unfiltered rather than down.
          strategy = "fast";
        };
      };
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

  # Pinned, not left to system.stateVersion. The module picks the major from
  # stateVersion (17 at 25.11, 18 at 26.11) and the data dir is per major, so
  # bumping stateVersion alone would start miniflux and immich on an empty
  # /var/lib/postgresql/18. A major upgrade is dump, bump this, restore.
  services.postgresql.package = pkgs.postgresql_17;

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

  # Limit build parallelism to avoid OOM
  nix.settings.max-jobs = 4;
  nix.settings.cores = 4;

  # Ops baseline the workstations get from hardware/performance.nix and
  # core/systemd-tweaks.nix via common.nix, which this host does not import.
  # The always-on box with the only copy of the photo library and the DNS
  # resolver had none of it.
  services.fstrim.enable = true;
  # As performance.nix does for the workstations: no atime writes on every
  # read of the photo library.
  fileSystems."/".options = ["noatime"];
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

  system.stateVersion = "26.11";
}
