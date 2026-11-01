# The Mullvad relay both setups dial: the workstations' own tunnel
# (system/networking/mullvad.nix) and the homeserver's exit node
# (system/networking/mullvad-exit.nix). A plain attrset like homeserver.nix.
# Public data, from api.mullvad.net/www/relays/wireguard/. Rented relays get
# renumbered or rekeyed now and then, so when the handshake stops, check here
# first.
{
  relay = {
    name = "at-vie-wg-001";
    publicKey = "GLqlOTVJCyRpJx3vgR3ykTPNJLGKNytHXu61zBWIAls=";
    endpoint = "146.70.116.130:51820";
  };
}
