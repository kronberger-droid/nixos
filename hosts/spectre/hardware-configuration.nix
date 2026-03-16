# Hardware configuration for spectre with btrfs impermanence.
# Replace every <PLACEHOLDER> with actual UUIDs from your disk.
#
# To find UUIDs after partitioning and formatting:
#   lsblk -f
# or:
#   blkid /dev/nvme0n1p1   (ESP)
#   blkid /dev/nvme0n1p2   (swap)
#   blkid /dev/nvme0n1p3   (btrfs)
{
  config,
  lib,
  modulesPath,
  ...
}: let
  btrfsUuid = "<BTRFS-UUID>";
  btrfsOpts = ["compress=zstd" "noatime"];
in {
  imports = [
    (modulesPath + "/installer/scan/not-detected.nix")
  ];

  boot = {
    initrd.availableKernelModules = ["xhci_pci" "thunderbolt" "nvme" "rtsx_pci_sdmmc"];
    initrd.kernelModules = [];
    kernelModules = ["kvm-intel"];
    extraModulePackages = [];

    # Wipe the ephemeral root subvolume on every boot.
    # This MUST be a systemd service because we use systemd initrd.
    # (boot.initrd.postResumeCommands does NOT work with systemd initrd)
    initrd.systemd.services.wipe-root = {
      description = "Wipe ephemeral btrfs root";
      wantedBy = ["initrd.target"];
      before = ["sysroot.mount"];
      after = ["dev-disk-by\\x2duuid-${btrfsUuid}.device"];
      unitConfig.DefaultDependencies = "no";
      serviceConfig.Type = "oneshot";
      script = ''
        mkdir -p /mnt
        mount -o subvol=/ /dev/disk/by-uuid/${btrfsUuid} /mnt

        if [ -d /mnt/@root ]; then
          btrfs subvolume delete /mnt/@root
        fi
        btrfs subvolume create /mnt/@root

        umount /mnt
      '';
    };
  };

  # --- Filesystems ---

  fileSystems."/" = {
    device = "/dev/disk/by-uuid/${btrfsUuid}";
    fsType = "btrfs";
    options = ["subvol=@root"] ++ btrfsOpts;
  };

  fileSystems."/nix" = {
    device = "/dev/disk/by-uuid/${btrfsUuid}";
    fsType = "btrfs";
    options = ["subvol=@nix"] ++ btrfsOpts;
    neededForBoot = true;
  };

  fileSystems."/nix/persist" = {
    device = "/dev/disk/by-uuid/${btrfsUuid}";
    fsType = "btrfs";
    options = ["subvol=@persist"] ++ btrfsOpts;
    neededForBoot = true;
  };

  fileSystems."/home" = {
    device = "/dev/disk/by-uuid/${btrfsUuid}";
    fsType = "btrfs";
    options = ["subvol=@home"] ++ btrfsOpts;
    neededForBoot = true;
  };

  fileSystems."/boot" = {
    device = "/dev/disk/by-uuid/<ESP-UUID>";
    fsType = "vfat";
    options = ["fmask=0077" "dmask=0077"];
  };

  swapDevices = [{device = "/dev/disk/by-uuid/<SWAP-UUID>";}];

  networking.useDHCP = lib.mkDefault true;

  nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";
  hardware.cpu.intel.updateMicrocode = lib.mkDefault config.hardware.enableRedistributableFirmware;
}
