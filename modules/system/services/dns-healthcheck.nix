{pkgs, ...}: let
  # Any name with a stable A record works. cloudflare.com is deliberately not
  # one of AdGuard's own upstream hostnames, so a filter rule or a rewrite
  # cannot make this probe pass while real lookups fail.
  probeName = "cloudflare.com";

  # Matches the DoH endpoints in hosts/homeserver/configuration.nix. Used only
  # to tell "the resolver broke" apart from "the uplink broke", never to answer
  # the probe itself.
  upstreamProbe = "https://1.1.1.1/dns-query?name=${probeName}&type=A";

  healthcheck = pkgs.writeShellApplication {
    name = "dns-healthcheck";
    runtimeInputs = with pkgs; [dnsutils curl systemd findutils];
    text = ''
      # Probe over loopback rather than the LAN address on purpose. This unit
      # answers exactly one question, "is the resolver itself alive", and a
      # broken LAN path to it is a different fault with a different fix. Mixing
      # the two would make the alert ambiguous at the moment it matters.
      if dig +short +time=3 +tries=1 @127.0.0.1 ${probeName} A \
         | grep -qE '^[0-9]+\.'; then
        exit 0
      fi

      echo "AdGuard did not resolve ${probeName} over loopback" >&2

      # Establish whether the uplink is at fault before reacting. Restarting
      # AdGuard during a WAN outage is worse than doing nothing: it cannot fix
      # anything, and it discards the cache that is still answering from memory
      # for everything already looked up.
      if ! curl -sS --max-time 8 -o /dev/null \
           -H 'accept: application/dns-json' '${upstreamProbe}'; then
        echo "DoH upstream is unreachable too, so this is an uplink fault rather than a resolver fault. Leaving AdGuard alone." >&2
        exit 1
      fi

      # Backoff. A persistently broken AdGuard (bad state file, corrupt filter
      # cache) used to get restarted every five minutes forever, each restart
      # re-copying the config, re-downloading filter lists and dropping
      # whatever cache was still answering. One restart per hour, then hands
      # off: a failure that survives a restart needs a human anyway.
      marker="$STATE_DIRECTORY/last-restart"
      if [ -e "$marker" ] && [ -n "$(find "$marker" -mmin -60)" ]; then
        echo "AdGuard was already restarted within the last hour and is still failing, so this needs a human. Not restarting again." >&2
        exit 1
      fi

      echo "DoH upstream is reachable, so AdGuard itself is at fault. Restarting it." >&2
      touch "$marker"
      systemctl restart adguardhome.service

      # AdGuard rebuilds its filter lists on start and refuses queries until it
      # has, so an immediate re-probe reports a false failure.
      sleep 15

      if dig +short +time=3 +tries=1 @127.0.0.1 ${probeName} A \
         | grep -qE '^[0-9]+\.'; then
        echo "recovered after restart" >&2
        exit 0
      fi

      echo "still failing after a restart, so this needs a human" >&2
      exit 1
    '';
  };
in {
  # Watchdog for LAN DNS.
  #
  # This exists because of a real outage: an ISP-side block on outbound UDP/53
  # meant AdGuard could not resolve its own DoH upstream hostnames at boot, so
  # it silently served nothing at all, not even over loopback. That took DNS
  # down for the whole LAN for hours and the only visible symptom was a phone
  # endlessly reconnecting to wifi, because every machine that could have
  # noticed resolves through Tailscale MagicDNS and never touches LAN DNS.
  #
  # The lesson encoded here is that the resolver has no natural observer. Every
  # admin path into this network deliberately bypasses it, thus it can fail
  # completely and silently. This unit is the observer.
  #
  # It intentionally does not page anyone. There is no notification service on
  # this host, and adding one to support a watchdog would be a larger dependency
  # than the watchdog. A failed oneshot is visible in `systemctl --failed` and
  # in the journal, which is enough to answer "is DNS broken" definitively. Wire
  # in ntfy or similar here if that ever stops being enough.
  systemd.services.dns-healthcheck = {
    description = "Verify AdGuard Home still resolves, and restart it if it alone is at fault";

    # Ordering only, not a dependency: if AdGuard is not running at all, this
    # unit should still run and report that fact rather than being skipped.
    #
    # Deliberately not ordered after network-online.target. Reporting "DNS is
    # down" while the network is down is the correct output, not a race to be
    # avoided, and pulling in that target would make this unit wait for the very
    # condition it exists to observe. The timer's OnBootSec covers boot timing.
    after = ["adguardhome.service"];

    serviceConfig = {
      Type = "oneshot";
      ExecStart = "${healthcheck}/bin/dns-healthcheck";
      # Holds the last-restart marker the backoff in the script checks.
      StateDirectory = "dns-healthcheck";
      # A root oneshot that runs dig, curl and one `systemctl restart` needs
      # none of root's reach. ProtectSystem is left off on purpose: the
      # restart goes through systemd's private socket under /run, and a
      # read-only /run is a cheap way to make that fail obscurely.
      NoNewPrivileges = true;
      PrivateTmp = true;
      ProtectHome = true;
      CapabilityBoundingSet = "";
      RestrictAddressFamilies = ["AF_INET" "AF_INET6" "AF_UNIX"];
    };
  };

  systemd.timers.dns-healthcheck = {
    wantedBy = ["timers.target"];
    timerConfig = {
      # Late enough after boot that AdGuard has loaded its filter lists, so a
      # reboot does not manufacture a failure and a spurious restart.
      OnBootSec = "3m";
      OnUnitActiveSec = "5m";

      # Nothing depends on the exact instant, and jitter keeps this from landing
      # on the same second as every other timer after a reboot.
      RandomizedDelaySec = "30s";
      Persistent = true;
    };
  };
}
