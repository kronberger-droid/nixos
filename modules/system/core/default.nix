{...}: {
  imports = [
    ./nix-settings.nix
    ./maintenance-schedule.nix
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
