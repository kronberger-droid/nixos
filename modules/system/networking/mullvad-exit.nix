{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.services.mullvad-exit;
  inherit (import ../../shared/mullvad.nix) relay;
  iface = "mullvad0";
  table = "51820";
  ip = "${pkgs.iproute2}/bin/ip";

  # Only what tailnet peers send through this box as their exit node takes
  # the tunnel. The server's own traffic never matches `iif tailscale0`, and
  # neither does anything addressed to it (local table) or to another tailnet
  # node (Tailscale's 5270), so cloudflared, deploys and blocky keep the home
  # uplink. Of the rest: routes more specific than a default in main (the LAN
  # behind the subnet route, docker bridges) stay there, everything else goes
  # to Mullvad, and if the tunnel is down, nowhere. Without that last rule an
  # empty table falls through to main and exit-node clients would leave with
  # the home address, without anyone noticing.
  #
  # Kept apart from the tunnel's own up and down, so a tunnel that fails at
  # boot or dies later leaves the rules, and with them the kill switch, in
  # place. `iif` takes an interface name before it exists.
  rules = add: ''
    for fam in -4 -6; do
      for prio in 10000 10001 10002; do
        while ${ip} $fam rule del priority $prio 2>/dev/null; do :; done
      done
      ${lib.optionalString add ''
      ${ip} $fam rule add iif tailscale0 lookup main suppress_prefixlength 0 priority 10000
      ${ip} $fam rule add iif tailscale0 lookup ${table} priority 10001
      ${ip} $fam rule add iif tailscale0 unreachable priority 10002
    ''}
    done
  '';
in {
  options.services.mullvad-exit = {
    enable = lib.mkEnableOption "Mullvad behind this host's Tailscale exit node";

    privateKeyFile = lib.mkOption {
      type = lib.types.str;
      description = "WireGuard private key registered with Mullvad";
    };

    addresses = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      example = ["10.67.12.34/32" "fc00:bbbb:bbbb:bb01::4:c22/128"];
      description = "Tunnel addresses Mullvad assigned to this key, IPv4 and IPv6";
    };
  };

  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = cfg.addresses != [];
        message = "services.mullvad-exit.addresses: set the tunnel addresses Mullvad assigned to this host's key";
      }
    ];

    # `table` keeps the tunnel's default routes out of main, where they would
    # take over the server's own default route.
    networking.wireguard.interfaces.${iface} = {
      ips = cfg.addresses;
      inherit (cfg) privateKeyFile;
      inherit table;
      peers = [
        {
          inherit (relay) publicKey endpoint;
          allowedIPs = ["0.0.0.0/0" "::/0"];
        }
      ];
    };

    # Before tailscaled, so there is no window in which it forwards exit
    # traffic without the rules.
    systemd.services.mullvad-exit-rules = {
      description = "Route Tailscale exit-node traffic through Mullvad";
      wantedBy = ["multi-user.target"];
      before = ["tailscaled.service"];
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
        ExecStart = pkgs.writeShellScript "mullvad-exit-rules-add" (rules true);
        ExecStop = pkgs.writeShellScript "mullvad-exit-rules-del" (rules false);
      };
    };

    # Replies come back on mullvad0 from internet addresses, and the strict
    # check routes those via the uplink and drops them.
    networking.firewall.checkReversePath = "loose";
  };
}
