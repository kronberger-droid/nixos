# Workstation security: the shared hardening plus the workstation firewall
# policy (SSH on the tailnet only). The homeserver imports hardening.nix
# directly and carries its own firewall, since it serves the LAN.
{
  config,
  lib,
  ...
}: let
  # The homeserver, tailnet and LAN (modules/shared/syncthing-devices.nix
  # carries the same pair).
  homeserver4 = "100.92.46.97,192.168.2.54";
  homeserver6 = "fd7a:115c:a1e0::35:2e61";
in {
  imports = [./hardening.nix];

  # SSH is only reachable over tailscale0 (below), so fail2ban has no
  # public-facing port to protect and would just tail the journal.
  services.fail2ban.enable = false;

  networking.firewall = {
    enable = true;
    allowPing = false;

    # NixOS-managed LOG rule; idempotent across firewall reloads. Replaces a
    # hand-rolled `iptables -A INPUT -j LOG` in extraCommands that duplicated
    # itself every time NetworkManager triggered a reload.
    logRefusedConnections = true;

    # Nothing else on every interface; SSH is scoped to tailscale0 below.
    # LocalSend: TCP 53317 for transfers, UDP 53317 for the multicast
    # announcements that let peers find this host and it find them.
    allowedTCPPorts = [53317];
    allowedUDPPorts = [53317];

    # SSH only over the tailnet. The per-interface option covers both
    # address families and is idempotent across reloads; the iptables
    # extraCommands line it replaces was IPv4-only, so SSH over the tailnet's
    # fd7a:: addresses was silently refused.
    interfaces."tailscale0".allowedTCPPorts = [22];

    # The sandbox account stays off the homeserver. Its rule there
    # (claude-sandbox-out in hosts/homeserver) only sees that host's own
    # claude uid, and the homeserver lets tailnet traffic through to the
    # published container ports, so from here the agent reached wiesinger's
    # containers after all. It needs nothing on that box directly: builds go
    # through root's nix-daemon and DNS through resolved. nixbld too, since a
    # fixed-output build the agent asks for runs as nixbld* with the host's
    # network. Same shape as the homeserver's chain: flushed on reload,
    # OUTPUT jumps added once.
    extraCommands = lib.mkIf config.security.agentSandbox.enable ''
      ip46tables -N claude-sandbox-out 2>/dev/null || true
      ip46tables -F claude-sandbox-out
      iptables -w -A claude-sandbox-out -d ${homeserver4} -j REJECT
      ip6tables -w -A claude-sandbox-out -d ${homeserver6} -j REJECT
      for ipt in iptables ip6tables; do
        for match in "--uid-owner claude" "--gid-owner nixbld"; do
          $ipt -w -C OUTPUT -m owner $match -j claude-sandbox-out 2>/dev/null \
            || $ipt -w -A OUTPUT -m owner $match -j claude-sandbox-out
        done
      done
    '';
    extraStopCommands = lib.mkIf config.security.agentSandbox.enable ''
      ip46tables -F claude-sandbox-out 2>/dev/null || true
    '';
  };
}
