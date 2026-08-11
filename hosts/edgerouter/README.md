# EdgeRouter X

Ubiquiti ER-X on EdgeOS, LAN gateway at `192.168.2.1`. Nix does not build this
box, so `config.boot` here is a snapshot for disaster recovery, not something
that gets applied. Refresh after any change committed on the router:

    nu hosts/edgerouter/pull-config.nu

The repo is public. The script redacts password hashes and key material, but
check `git diff` before committing: a new EdgeOS release can add a
secret-bearing node the patterns do not know about.

## Settings that look wrong but are not

`source-validation loose`, not `strict`. Strict reverse-path filtering drops
packets from the phone, which sources traffic from its cellular address over
wifi while Tailscale is up.

`WANv6_LOCAL rule 40` matches destination port 546 only. The setup wizard also
pinned source port 547, which is what RFC 8415 says a DHCPv6 server sends from,
but Magenta replies from an ephemeral port, so replies were silently dropped.
Dormant while IPv6 is off, correct for whenever it is not.

## DNS goes to AdGuard on homeserver

Forced, not preferred. Magenta blocks outbound UDP/53 to every destination
including their own resolver, thus dnsmasq has no upstream it can reach, since
it only speaks plain DNS. AdGuard resolves over DoH on TCP/443, which the block
does not touch. DHCP hands out `192.168.2.54` and dnsmasq forwards there too.

The consequence is that homeserver going down takes LAN DNS with it, and no
fallback is possible on this line. `modules/system/services/dns-healthcheck.nix`
is the watchdog.

## IPv6 is off, and cannot currently be turned on

Magenta offers no prefix delegation on any tariff. Bridge mode, which this line
runs, is IPv4 only; router mode gives a bare /64 with delegation disabled.
Neither yields a routable prefix for a LAN behind our own router.

Measured: DHCPv6 answers `NoPrefixAvail` for both /56 (5 of 5) and /64 (3 of 3),
and the reply carries `3ffe:501:ffff:101::1`, a deprecated 6bone example address
that reads like placeholder data. SLAAC will still configure
`2001:4bc9:b057:9a2b::/64` on eth0 and install a default route, but nothing
routes past the gateway. An address appearing is not evidence of working v6.

If this is ever retried, eth0 needs `accept_ra=2`, not `1`. With forwarding on,
always true on a router, the kernel ignores RAs for default-route installation,
so `=1` yields an address with no route and every connectivity test fails for
the wrong reason.

    set interfaces ethernet eth0 ipv6 address autoconf
    set interfaces ethernet eth0 ipv6 dup-addr-detect-transmits 1
    set interfaces ethernet eth0 dhcpv6-pd rapid-commit enable
    set interfaces ethernet eth0 dhcpv6-pd pd 0 prefix-length /56
    set interfaces ethernet eth0 dhcpv6-pd pd 0 interface switch0 host-address ::1
    set interfaces ethernet eth0 dhcpv6-pd pd 0 interface switch0 prefix-id :1
    set interfaces ethernet eth0 dhcpv6-pd pd 0 interface switch0 service slaac

`prefix-id` is only valid when the delegation is shorter than /64.

## DPI stays off

`traffic-analysis dpi disable`. `tdts` is a 441 KB Trend Micro module on a 256 MB
MIPS box and only feeds the GUI graphs.

The config setting stops traffic being fed to the engine but does not stop the
modules loading: `ubnt_nf_app` and `tdts` are back in `lsmod` after every boot
regardless. `rmmod ubnt_nf_app tdts` unloads them until the next reboot, and
there is no config knob that makes it stick.

Not worth automating. DPI was a suspect during the UDP/53 investigation and was
cleared: unloading both modules changed nothing, so they are inert here and cost
only the memory.
