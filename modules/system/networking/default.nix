{...}: {
  imports = [
    ./networking.nix
    ./iwd.nix
    ./pia.nix
    ./mullvad.nix
    ./tuwien-vpn.nix
    ./tunet.nix
  ];
}
