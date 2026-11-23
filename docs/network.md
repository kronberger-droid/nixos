# Network

## Shape

```
internet ── Magenta modem (bridge) ── EdgeRouter 192.168.2.1 ── LAN 192.168.2.0/24
                                                                  ├─ homeserver  .54   DNS, subnet router, exit node
                                                                  ├─ access point .38
                                                                  └─ Bambu printer .39

tailnet (100.64.0.0/10): homeserver, intelNuc, spectre, P14E, phone
```

Two networks matter. The LAN is what is plugged in at home. The tailnet is
what every machine of mine is on wherever it is, and it is the network
services are written for: ports are opened on `tailscale0`, names resolve
through MagicDNS.

## Tailscale

- Every host runs it. Workstations accept routes and act as clients
  (`modules/system/networking/networking.nix`).
- The homeserver advertises `192.168.2.0/24`, so the router, the access point
  and the printer are reachable from anywhere without running Tailscale
  themselves. It also offers itself as an exit node whose traffic leaves
  through Mullvad, mostly for the phone.
- Two things live in the admin console and not in this repo: approving the
  subnet route and the exit node, and the tailnet DNS settings.
- "Override local DNS" in the admin console must stay off. With it on, the
  workstations' Mullvad tunnel leaks DNS around itself, and the tunnel refuses
  to start (`modules/system/networking/mullvad.nix`).

```nu
tailscale status                 # who is up, direct or relayed
tailscale ping homeserver        # "via DERP" means relayed, slower and flakier
```

## Firewall

| Host | Open on the LAN | Open on the tailnet |
|------|-----------------|---------------------|
| Workstations | nothing | 22, Syncthing 22000 |
| Homeserver | 22, 53 | 22, 53 and every service port, see [homeserver.md](homeserver.md#services) |

Docker's published ports bypass the NixOS firewall, so the homeserver scopes
them to the tailnet in the `DOCKER-USER` chain.

## DNS

The LAN's resolver is blocky on the homeserver, port 53. DHCP hands out
`192.168.2.54` and the router forwards there as well.

This is forced, not a preference. The ISP blocks outbound UDP/53 to every
destination, so nothing that speaks plain DNS can resolve anything. blocky
talks DNS over HTTPS to IP-literal upstreams (Mullvad first, Quad9 as
fallback), which the block does not touch.

The consequence: when the homeserver is down, LAN DNS is down, and there is
no fallback this line allows. `dns-healthcheck` runs every five minutes on
the server and restarts blocky when the resolver is dead but the uplink is
not.

```sh
# on the homeserver
systemctl status blocky dns-healthcheck
journalctl -u dns-healthcheck -n 30
dig @127.0.0.1 cloudflare.com        # does the resolver answer?
```

blocky has no web UI and no API on purpose. Blocklists and local names are in
`hosts/homeserver/configuration.nix`; `photos.home.lan` is the one local name
and answers with the tailnet address.

Workstations use systemd-resolved with the homeserver's LAN address first and
Cloudflare and Quad9 over TLS behind it, plus the StevenBlack hosts list in
`/etc/hosts`.

## VPNs

All three workstations import `modules/profiles/vpn-workstation.nix`. Mullvad
only switches on where the host has a key in `secrets/` (intelNuc and P14E so
far). The bar's VPN module toggles them; by hand:

| VPN | Start | Stop | Notes |
|-----|-------|------|-------|
| Mullvad (WireGuard) | `sudo systemctl start mullvad-wg` | `sudo systemctl stop mullvad-wg` | Comes up at login. One key per host, in agenix. |
| TU Wien (OpenConnect) | `tuwien-vpn start` | `tuwien-vpn stop` | Password and TOTP come from agenix, no prompt. `tuwien-vpn status` for scripts. |
| PIA (WireGuard) | `sudo systemctl start pia-vpn` | `sudo systemctl stop pia-vpn` | |

The `systemctl` calls for these units need no password.

## Wifi

`tunet` (TU Wien, WPA2 Enterprise) is declared with a pinned CA chain in
`modules/system/networking/tunet.nix`. When TU Wien changes CA, connecting
fails with a certificate error in the journal and the chain file needs
refreshing from cat.eduroam.org.

P14E runs iwd without NetworkManager; `modules/system/networking/iwd.nix`
describes the stages.

## Router

The EdgeRouter is not built by Nix. `hosts/edgerouter/config.boot` is a
snapshot for disaster recovery, and
[hosts/edgerouter/README.md](../hosts/edgerouter/README.md) lists the settings
that look wrong and are not: loose source validation, the DHCPv6 firewall
rule, IPv6 being off, DPI being off. Read it before touching any of those.
Logging in is in [access.md](access.md#edgerouter).
