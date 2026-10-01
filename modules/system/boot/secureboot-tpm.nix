# Lanzaboote Secure Boot plus TPM2 auto-unlock of the LUKS root. One module
# rather than two toggles, since the second is worthless without the first:
# the TPM seals the key against PCR 7, which records the Secure Boot state.
# With Secure Boot off, anything booted from a USB stick sees the same PCR 7
# and is handed the key.
#
# Expects the LUKS mapper to be called "nixos-root", which holds for the
# laptops' hand-made layout and for boot/disk-layout.nix alike.
#
# Neither half is finished by a rebuild. Keys have to be enrolled in the
# firmware and the TPM slot added, by hand, in this order:
#   sbctl enroll-keys -m        (firmware in Setup Mode)
#   enable Secure Boot in the firmware, reboot, `sbctl verify`
#   systemd-cryptenroll --tpm2-device=auto /dev/disk/by-partlabel/disk-main-luks
# Enrolling the TPM before Secure Boot is on seals against the wrong PCR 7;
# it fails safe, back to the passphrase prompt, but has to be redone.
{
  pkgs,
  lib,
  inputs,
  ...
}: {
  imports = [inputs.lanzaboote.nixosModules.lanzaboote];

  boot = {
    # Lanzaboote replaces systemd-boot for Secure Boot
    systemd-boot-defaults.enable = false;
    loader.systemd-boot.enable = lib.mkForce false;
    loader.efi.canTouchEfiVariables = false;
    # systemd-boot-defaults is off here, so boot-systemd.nix's editor = false
    # never applies; lanzaboote copies this value into loader.conf regardless.
    # With TPM auto-unlock, an editable cmdline (init=/bin/sh) is root on the
    # decrypted disk, which is the one thing Secure Boot exists to stop.
    loader.systemd-boot.editor = false;
    lanzaboote = {
      enable = true;
      pkiBundle = "/var/lib/sbctl";
      configurationLimit = 20;
    };
    initrd.luks.devices."nixos-root".crypttabExtraOpts = ["tpm2-device=auto"];
    initrd.systemd.tpm2.enable = true;
  };

  # TPM2 support for Secure Boot + LUKS auto-unlock
  security.tpm2 = {
    enable = true;
    pkcs11.enable = false;
    tctiEnvironment.enable = true;
  };

  # systemd 258 added systemd-pcrlogin@.service: logind runs it for every
  # new user and it extends an NvPCR named "login" with the user record. It
  # is ordering-only (user-runtime-dir@ has After= but no Wants=, and the
  # unit's own comment says a failure must never block login), nothing here
  # seals against that NvPCR, and on intelNuc it fails anyway with "TPM NV
  # index space is exhausted". What it does cost is ~0.5 s, serially, before
  # the greeter's session and again before the user's: a second of boot for
  # nothing. Masked.
  systemd.units."systemd-pcrlogin@.service".enable = false;

  environment.systemPackages = [pkgs.sbctl];
}
