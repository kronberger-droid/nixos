{...}: {
  imports = [
    ../modules/system/nix-settings.nix
    ../modules/system/networking.nix
    ../modules/system/locale.nix
    ../modules/system/audio.nix
    ../modules/system/desktop.nix
    ../modules/system/systemd-tweaks.nix
    ../modules/system/users.nix
    ../modules/system/fonts.nix
    ../modules/system/packages.nix
    ../modules/system/kernel.nix
    ../modules/system/megasync.nix
    ../modules/system/agenix.nix
    ../modules/system/keyd.nix
    ../modules/system/virtualisation.nix
    ../modules/system/gnome-keyring.nix
    ../modules/system/performance.nix
    ../modules/system/security.nix
    ../modules/system/power-management.nix
    ../modules/system/pia.nix
    ../modules/system/tuwien-vpn.nix
  ];
}
