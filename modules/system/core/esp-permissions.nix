# Tighten the EFI System Partition so its contents are not world readable.
#
# This is policy rather than a hardware fact, thus it lives here instead of in
# each host's generated hardware-configuration.nix. `nixos-generate-config`
# has no opinion of its own: for vfat it copies whatever mask the partition
# happened to be mounted with at generation time, so a plain `mount` during
# install (umask 0022) bakes world-readable into the generated file forever.
#
# What that costs: vfat carries no per-file permissions, so one mask covers the
# whole mount, and at 0022 any local user can read /boot/loader/random-seed.
# systemd-boot-random-seed says so on every boot:
#
#     Mount point '/boot' which backs the random seed file is world
#     accessible, which is a security hole!
#
# mkForce rather than a plain assignment, since fileSystems.<name>.options is a
# list and NixOS merges lists by concatenation. Without it the generated
# fmask=0022 would simply sit in front of ours in the mount string.
{lib, ...}: {
  fileSystems."/boot".options = lib.mkForce ["fmask=0077" "dmask=0077"];
}
