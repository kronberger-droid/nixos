# PLACEHOLDER — this host has not been installed yet.
#
# Replace this entire file with the real output of `nixos-generate-config`
# run against the actual disk during install. The device UUIDs below are
# fake and will not build. Shape mirrors spectre's LUKS-root + vfat-boot
# layout since that's the intended install target here too; adjust if the
# real partitioning differs.
{
  config,
  lib,
  modulesPath,
  ...
}: {
  imports = [
    (modulesPath + "/installer/scan/not-detected.nix")
  ];

  boot.initrd.availableKernelModules = ["xhci_pci" "thunderbolt" "nvme" "usb_storage" "sd_mod"];
  boot.initrd.kernelModules = [];
  boot.kernelModules = ["kvm-intel"];
  boot.extraModulePackages = [];

  fileSystems."/" = {
    device = "/dev/mapper/nixos-root";
    fsType = "ext4";
  };

  boot.initrd.luks.devices."nixos-root".device = "/dev/disk/by-uuid/00000000-0000-0000-0000-000000000000";

  fileSystems."/boot" = {
    device = "/dev/disk/by-uuid/0000-0000";
    fsType = "vfat";
    options = ["fmask=0022" "dmask=0022"];
  };

  swapDevices = [];

  nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";
  hardware.cpu.intel.updateMicrocode = lib.mkDefault config.hardware.enableRedistributableFirmware;
}
