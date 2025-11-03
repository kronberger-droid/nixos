{ pkgs, ... }:
{
  # Intel VBT (Video BIOS Table) firmware fix for duplicate eDP entries
  # This fixes display issues on devices with duplicate eDP entries in their VBT
  # by loading a modified VBT that zeros out the duplicate entry.

  hardware.firmware = [
    (pkgs.runCommand "intel-vbt-fix" { } ''
      mkdir -p $out/lib/firmware
      cp ${./vbt_modified} $out/lib/firmware/modified_vbt
    '')
  ];

  # Kernel parameter to use the modified VBT
  boot.kernelParams = [
    "i915.vbt_firmware=modified_vbt"
  ];
}
