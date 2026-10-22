# The homeserver's addresses, for everything that dials it or must not. A
# plain attrset like host-keys.nix, so agenix-free and nixpkgs-free callers
# (syncthing-devices.nix, droid) can import it too. The tailnet ones are
# Tailscale's assignment and only change if the node is re-registered.
{
  tailnet4 = "100.92.46.97";
  tailnet6 = "fd7a:115c:a1e0::35:2e61";
  lan4 = "192.168.2.54";
  lanSubnet = "192.168.2.0/24";
}
