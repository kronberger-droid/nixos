{...}: {
  imports = [
    ./desktop.nix
    ./greetd.nix
    # ./keyring.nix  # replaced by oo7-nixos
    ./keyd.nix
  ];
}
