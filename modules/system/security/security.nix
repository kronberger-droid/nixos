# Workstation security: the shared hardening plus the workstation firewall
# policy (SSH on the tailnet only). The homeserver imports hardening.nix
# directly and carries its own firewall, since it serves the LAN.
{...}: {
  imports = [./hardening.nix];

  networking.firewall = {
    enable = true;
    allowPing = false;

    # NixOS-managed LOG rule; idempotent across firewall reloads. Replaces a
    # hand-rolled `iptables -A INPUT -j LOG` in extraCommands that duplicated
    # itself every time NetworkManager triggered a reload.
    logRefusedConnections = true;

    # Nothing on every interface. SSH is scoped to tailscale0 below.
    allowedTCPPorts = [];
    allowedUDPPorts = [];

    # Allow specific applications through the firewall
    allowedTCPPortRanges = [
      # LocalSend port range
      {
        from = 53317;
        to = 53317;
      }
    ];

    # SSH only over the tailnet. The per-interface option covers both
    # address families and is idempotent across reloads; the iptables
    # extraCommands line it replaces was IPv4-only, so SSH over the tailnet's
    # fd7a:: addresses was silently refused.
    interfaces."tailscale0".allowedTCPPorts = [22];
  };
}
