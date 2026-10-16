{
  config,
  lib,
  pkgs,
  username,
  ...
}: let
  cfg = config.services.quickemu;
in {
  # Off by default: the VMs are occasional, and the libvirt/podman stack that
  # used to sit here went unused. quickemu wraps its own qemu, swtpm and OVMF,
  # so the package plus device access is all it needs. Turning this on also
  # brings back the ~/Emulation configs and the `emu` command on the home side
  # (apps/quickemu.nix, shell/nushell.nix).
  options.services.quickemu.enable = lib.mkEnableOption "quickemu VMs";

  config = lib.mkIf cfg.enable {
    environment.systemPackages = [pkgs.quickemu];
    # USB passthrough into the SPICE display.
    virtualisation.spiceUSBRedirection.enable = true;
    users.users.${username}.extraGroups = ["kvm"];
  };
}
