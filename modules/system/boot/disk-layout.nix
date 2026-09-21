# Declarative disk layout via disko, for hosts that import this file:
#
#   ESP (vfat, /boot)
#   LUKS "nixos-root"
#     LVM vg "pool"
#       swap   fixed size, the hibernation resume device
#       root   ext4, everything that is left
#
# Nothing here depends on the size of the disk, and nothing is mounted by
# UUID: disko derives the fileSystems, swapDevices and initrd LUKS entries
# from partition labels and LV names, all of which are known before the disk
# is formatted. That is what lets the recovery stick carry an install-ready
# config, where hardware-configuration.nix used to need UUIDs pasted back in
# after partitioning.
#
# LVM sits inside LUKS for the sake of swap. A swapfile on the root fs (what
# spectre and P14E do) needs a resume_offset, which only exists once the file
# does; a second LUKS partition would need its own unlock. An LV has a stable
# name, /dev/pool/swap, behind the one passphrase.
#
# The mapper name matches the laptops, so modules/profiles/secureboot-laptop.nix
# and the TPM enrollment steps apply unchanged.
#
# Install, from the recovery stick:
#   disko --mode destroy,format,mount --flake /nixos-config#<host>
#   nixos-install --flake /nixos-config#<host>
# disko asks for the LUKS passphrase. It only ever runs when called like
# this; nixos-rebuild never repartitions, and editing this file does nothing
# to a disk that is already formatted.
#
# This sits on top of the host's hardware-configuration.nix, which stays a
# generated file. Regenerate it with
#   nixos-generate-config --no-filesystems --show-hardware-config
# since the default output declares fileSystems and swapDevices by UUID, and
# those collide with the ones disko derives here.
{
  lib,
  config,
  inputs,
  ...
}: let
  cfg = config.disk-layout;
in {
  imports = [inputs.disko.nixosModules.disko];

  # No defaults: these are the two facts that differ per machine, and a
  # guessed device is the wrong disk formatted.
  options.disk-layout = {
    device = lib.mkOption {
      type = lib.types.str;
      example = "/dev/disk/by-id/nvme-CT1000P3PSSD8_24344A99EF58";
      description = "Disk to install on. Use a by-id path, nvme0n1 can move.";
    };
    swapSize = lib.mkOption {
      type = lib.types.str;
      example = "20G";
      description = "Size of the swap LV. At least RAM, or hibernation fails when memory is full.";
    };
  };

  config.disko.devices = {
    disk.main = {
      type = "disk";
      inherit (cfg) device;
      content = {
        type = "gpt";
        partitions = {
          ESP = {
            # 1G, not the 512M intelNuc had: a kernel/initrd pair is ~60M and
            # that ESP filled at 8 generations.
            size = "1G";
            type = "EF00";
            content = {
              type = "filesystem";
              format = "vfat";
              mountpoint = "/boot";
              # core/esp-permissions.nix forces the same mask on the running
              # system. Repeated here since disko also uses it for the mount
              # that nixos-install writes the random seed through.
              mountOptions = ["fmask=0077" "dmask=0077"];
            };
          };
          luks = {
            size = "100%";
            content = {
              type = "luks";
              name = "nixos-root";
              settings.allowDiscards = true;
              content = {
                type = "lvm_pv";
                vg = "pool";
              };
            };
          };
        };
      };
    };

    lvm_vg.pool = {
      type = "lvm_vg";
      lvs = {
        swap = {
          size = cfg.swapSize;
          content = {
            type = "swap";
            # Sets boot.resumeDevice. It has to be named, since zram is
            # active as swap too and auto-detection would not pick this one.
            resumeDevice = true;
          };
        };
        # disko creates the 100% LV last regardless of attribute order.
        root = {
          size = "100%";
          content = {
            type = "filesystem";
            format = "ext4";
            mountpoint = "/";
          };
        };
      };
    };
  };
}
