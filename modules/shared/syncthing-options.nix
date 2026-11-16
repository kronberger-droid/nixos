# Syncthing options, shared by modules/system/services/syncthing.nix
# (homeserver) and modules/home-manager/apps/syncthing.nix (everything else),
# for the same reason as syncthing-ignores.nix.
#
# Sync runs over the tailnet and nothing else. Every peer in
# syncthing-devices.nix has a fixed 100.x address, so discovery has nothing to
# find and relays have nothing to bridge. With all four off, a peer that is not
# reachable on the tailnet does not sync, and nothing leaves through
# Syncthing's public discovery servers or relay pool.
{
  urAccepted = -1; # no usage reporting
  relaysEnabled = false;
  globalAnnounceEnabled = false;
  localAnnounceEnabled = false;
  natEnabled = false;
  # TCP only. The default also listens on QUIC and on a relay; the firewall
  # opens 22000/tcp on tailscale0 alone.
  listenAddresses = ["tcp://:22000"];
}
