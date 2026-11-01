{
  config,
  lib,
  pkgs,
  username,
  ...
}: let
  cfg = config.services.mullvad-wg;
  iface = "mullvad0";
  # Fwmark and routing table both, as wg-quick does. Bits 16-23 must stay
  # clear: Tailscale matches its own packets on 0x80000/0xff0000.
  table = 51820;

  # networkd skips a netdev whose key file is missing and does not look
  # again. agenix writes the key from its own unit, which can lose that
  # race at boot or on a switch, so reload first and wait for the link.
  #
  # DNS needs the tailnet's "Override local DNS" off. With it on, tailscale0
  # holds `~.` as well, two `~.` links are asked in parallel, and tailscaled
  # forwards its half upstream with the bypass mark, around the tunnel.
  # Rewriting tailscale0 from here does not hold: tailscaled re-applies its
  # DNS config on every major link change, this tunnel coming up included.
  # With the setting off, tailscale0 carries only the tailnet suffix, which
  # outranks `~.` for MagicDNS names. Refuse to start rather than leak.
  up = pkgs.writeShellScript "mullvad-wg-up" ''
    ${pkgs.systemd}/bin/networkctl reload
    for _ in $(seq 50); do
      ${pkgs.iproute2}/bin/ip link show ${iface} >/dev/null 2>&1 && break
      sleep 0.1
    done
    ${lib.optionalString config.services.tailscale.enable ''
      if ${pkgs.systemd}/bin/resolvectl domain tailscale0 2>/dev/null | grep -q '~\.'; then
        echo "tailscale0 routes all DNS (~.); turn off 'Override local DNS' in the tailnet's DNS settings" >&2
        exit 1
      fi
    ''}
    exec ${pkgs.systemd}/bin/networkctl up ${iface}
  '';
in {
  options.services.mullvad-wg = {
    enable = lib.mkEnableOption "Mullvad over plain WireGuard (networkd)";

    privateKeyFile = lib.mkOption {
      type = lib.types.str;
      description = "WireGuard private key registered with Mullvad, readable by systemd-network";
    };

    addresses = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      example = ["10.67.12.34/32" "fc00:bbbb:bbbb:bb01::4:c22/128"];
      description = "Tunnel addresses Mullvad assigned to this key, IPv4 and IPv6";
    };

    relay = {
      publicKey = lib.mkOption {
        type = lib.types.str;
        default = "GLqlOTVJCyRpJx3vgR3ykTPNJLGKNytHXu61zBWIAls=";
        description = "Relay public key (at-vie-wg-001 by default)";
      };
      endpoint = lib.mkOption {
        type = lib.types.str;
        default = "146.70.116.130:51820";
        description = "Relay endpoint, an address so bringing the link up needs no DNS";
      };
    };

    # Mullvad's public base.dns.mullvad.net (ads, trackers, malware), the
    # nearest thing to blocky while away from it, asked through the tunnel.
    # Not the in-tunnel filtering resolvers the config generator offers:
    # those are 100.64.0.x, Tailscale's CGNAT range, and its firewall drops
    # 100.64/10 arriving off tailscale0.
    dns = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = ["194.242.2.4#base.dns.mullvad.net" "2a07:e340::4#base.dns.mullvad.net"];
      description = "Resolvers asked through the tunnel, over DoT";
    };
  };

  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = cfg.addresses != [];
        message = "services.mullvad-wg.addresses: set the tunnel addresses Mullvad assigned to this host's key";
      }
    ];

    systemd.network = {
      enable = true;

      # networkd deletes routing rules it did not write when it reloads or
      # configures a link, Tailscale's 5210-5270 among them; tailscaled puts
      # them back, but the tailnet drops out in between.
      config.networkConfig.ManageForeignRoutingPolicyRules = false;

      netdevs."50-${iface}" = {
        netdevConfig = {
          Kind = "wireguard";
          Name = iface;
        };
        wireguardConfig = {
          PrivateKeyFile = cfg.privateKeyFile;
          FirewallMark = table;
          RouteTable = table;
        };
        wireguardPeers = [
          {
            PublicKey = cfg.relay.publicKey;
            Endpoint = cfg.relay.endpoint;
            AllowedIPs = ["0.0.0.0/0" "::/0"];
          }
        ];
      };

      # The wg-quick pair of rules: anything not from the tunnel itself
      # goes to its table, except routes more specific than a default in
      # main (the LAN). Both sit after Tailscale's 5210-5270, so tailnet
      # addresses and accepted subnet routes resolve in table 52 first, and
      # tailscaled's own marked packets look up main at 5210 and leave
      # outside the tunnel, which keeps direct peer connections working.
      networks."50-${iface}" = {
        matchConfig.Name = iface;
        address = cfg.addresses;
        inherit (cfg) dns;
        domains = ["~."];
        networkConfig = {
          DNSDefaultRoute = true;
          # Strict here, unlike the global opportunistic (networking.nix):
          # these servers do speak DoT, so a failure should fail, not fall
          # back to plain DNS.
          DNSOverTLS = true;
          LLMNR = false;
          MulticastDNS = false;
        };
        linkConfig = {
          ActivationPolicy = "manual";
          RequiredForOnline = "no";
        };
        routingPolicyRules = [
          {
            Table = "main";
            SuppressPrefixLength = 0;
            Priority = 10000;
            Family = "both";
          }
          {
            FirewallMark = table;
            InvertRule = true;
            Table = table;
            Priority = 10001;
            Family = "both";
          }
        ];
      };
    };

    networking.networkmanager.unmanaged = [iface];

    # Strict reverse-path filtering looks up the relay's replies without the
    # fwmark, finds the tunnel instead of the uplink and drops them.
    # Tailscale's client mode already sets loose; this holds without it.
    networking.firewall.checkReversePath = lib.mkDefault "loose";

    # Down at boot, like PIA: started from the bar or by hand.
    systemd.services.mullvad-wg = {
      description = "Mullvad WireGuard tunnel";
      after = ["systemd-networkd.service" "tailscaled.service"];
      wants = ["systemd-networkd.service"];
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
        ExecStart = up;
        ExecStop = "${pkgs.systemd}/bin/networkctl down ${iface}";
      };
    };

    security.sudo-rs.extraRules = [
      {
        users = [username];
        commands = [
          {
            command = "/run/current-system/sw/bin/systemctl start mullvad-wg.service";
            options = ["NOPASSWD"];
          }
          {
            command = "/run/current-system/sw/bin/systemctl stop mullvad-wg.service";
            options = ["NOPASSWD"];
          }
          {
            command = "/run/current-system/sw/bin/systemctl restart mullvad-wg.service";
            options = ["NOPASSWD"];
          }
        ];
      }
    ];
  };
}
