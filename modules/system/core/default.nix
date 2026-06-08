{...}: {
  imports = [
    ./nix-settings.nix
    ./locale.nix
    ./users.nix
    ./packages.nix
    ./helium.nix
    ./fonts.nix
    ./systemd-tweaks.nix
    ./kernel.nix
  ];
}
