{...}: {
  imports = [
    ./nix-settings.nix
    ./activation.nix
    ./locale.nix
    ./users.nix
    ./packages.nix
    ./helium.nix
    ./fonts.nix
    ./systemd-tweaks.nix
    ./kernel.nix
    ./esp-permissions.nix
  ];
}
