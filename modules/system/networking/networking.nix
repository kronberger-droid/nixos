{
  host,
  lib,
  ...
}: {
  networking = {
    networkmanager = {
      enable = lib.mkDefault true;
      settings = {
        main = {
          dns = "systemd-resolved";
          rc-manager = "symlink";
        };
        device = {
          "wifi.scan-rand-mac-address" = "yes";
        };
        connection = {
          "wifi.cloned-mac-address" = "stable";
          "ethernet.cloned-mac-address" = "stable";
        };
      };
    };
    hostName = host;
    enableIPv6 = true;

    # Block adult/ad domains via the StevenBlack hosts list (rewrites /etc/hosts).
    # Consulted by libc before DNS, so it applies regardless of upstream resolver.
    stevenblack = {
      enable = true;
      block = ["porn"];
    };
  };

  # NetworkManager handles all networking; disable systemd-networkd to avoid
  # duplicate link management and spurious UP/DOWN log spam
  # Note: systemd-networkd stays enabled because the PIA VPN module uses it
  # for WireGuard interface management. NM handles wifi/ethernet, networkd
  # handles PIA's pia0 interface. The coexistence is fine.

  # A way to resolve names when the homeserver's blocky is down. The link
  # DNS from DHCP is that box alone, and resolved's FallbackDNS only applies
  # while no server is configured at all, so it never kicked in; plain
  # 1.1.1.1 would not have answered anyway, since the ISP drops outbound
  # UDP/53 (hosts/edgerouter/README.md).
  #
  # So a global server list on top of the link's: blocky first, Cloudflare
  # and Quad9 over DoT (TCP/853 is not blocked) behind it. resolved asks the
  # servers of one scope in turn and moves on only when the current one
  # fails, so blocky still answers everything while it is up and its
  # blocking stays in force. Opportunistic, not strict: it applies to every
  # server, blocky speaks no DoT, and opportunistic falls back to plain DNS
  # for that one. Tailscale's MagicDNS already falls through to Cloudflare
  # while tailscaled runs; this covers the times it does not.
  services.resolved = {
    enable = true;
    settings.Resolve = {
      MulticastDNS = "no";
      DNS = ["192.168.2.54" "1.1.1.1#cloudflare-dns.com" "9.9.9.9#dns.quad9.net"];
      DNSOverTLS = "opportunistic";
      FallbackDNS = "1.1.1.1#cloudflare-dns.com 1.0.0.1#cloudflare-dns.com 9.9.9.9#dns.quad9.net";
    };
  };
  # Every host accepts the subnet routes homeserver advertises, so the LAN is
  # reachable from anywhere: the EdgeRouter, the AP and the Bambu printer, none
  # of which can run Tailscale. Linux needs --accept-routes explicitly; iOS and
  # Android take advertised routes on their own.
  #
  # Both settings are mkDefault so homeserver can override them with its
  # subnet-router role. That works because the module system keeps only the
  # highest-priority definitions: homeserver's normal-priority "server" and its
  # --advertise-routes replace these outright rather than merging with them,
  # which matters for extraSetFlags, since lists would otherwise concatenate and
  # hand the router a contradictory --accept-routes.
  services.tailscale = {
    enable = true;

    # "client" loosens reverse-path filtering, which a host receiving traffic
    # over an accepted route needs. It does not imply --accept-routes; that flag
    # is separate and set below.
    useRoutingFeatures = lib.mkDefault "client";
    extraSetFlags = lib.mkDefault ["--accept-routes"];
  };

  # Syncthing ports (service runs as user via Home Manager)
  networking.firewall = {
    allowedTCPPorts = [22000];
    allowedUDPPorts = [22000 21027];
  };
}
