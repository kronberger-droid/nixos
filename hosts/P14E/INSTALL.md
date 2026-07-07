# P14E install checklist

## Partition & install
- [ ] Boot NixOS installer, connect network
- [ ] Partition: EFI/vfat boot + LUKS2 root (ext4 inside), matching spectre's layout
- [ ] `nixos-generate-config --root /mnt`, then replace
      `hosts/P14E/hardware-configuration.nix` with the generated file
      (keep the LUKS `boot.initrd.luks.devices."nixos-root"` line — name must
      stay `nixos-root` to match `configuration.nix`)
- [ ] `nixos-install --root /mnt --flake .#P14E`

## First boot
- [ ] Check real thread count: `nproc` — fix `nix.settings.cores` in
      `hosts/P14E/configuration.nix` if it's not 8 threads (currently set to 4,
      assuming 4c/8t)
- [ ] Get SSH host key: `cat /etc/ssh/ssh_host_ed25519_key.pub` — add to
      `secrets/secrets.nix` recipients list, then rekey the secrets you want
      this host to access
- [ ] Get syncthing device ID (`syncthing -device-id` or web UI) — add a
      `P14E` entry to `modules/shared/syncthing-devices.nix`

## Secure Boot + TPM2 (lanzaboote)
- [ ] `sbctl create-keys`
- [ ] `sbctl enroll-keys` (add `-m` if you need Microsoft's keys for other
      dual-boot OSes)
- [ ] Reboot into firmware setup, set Secure Boot to "enrolled/user mode"
- [ ] `sbctl verify` after reboot to confirm signed boot files
- [ ] `systemd-cryptenroll --tpm2-device=auto /dev/<luks-partition>` to bind
      the LUKS key to the TPM — without this step the config expects TPM
      auto-unlock but it won't actually be enrolled, so it'll fall back to
      password prompt every boot

## Hardware quirks to verify (don't assume — check and adjust)
- [ ] Camera: `v4l2-ctl --list-devices` + `dmesg | grep -i ipu6` — confirm
      sensor is actually `hi556`/`ov2740` (in
      `modules/system/hardware/ipu6-camera.nix`); swap module names if not
- [ ] Display: `dmesg | grep -i vbt` — only if you see duplicate-eDP/VBT
      warnings is spectre's `modules/system/hardware/firmware/vbt.nix`
      pattern relevant, and even then you'd need a fresh VBT dump for *this*
      panel, not spectre's file
- [ ] Touchpad: `libinput list-devices` — add per-device tuning to
      `modules/home-manager/desktop/niri.nix` / `sway.nix` if it needs it
      (spectre's touchpad ID won't match this hardware)
- [ ] HiDPI scale: panel is 3000×2000 on 13.9" (~260 DPI, notably denser than
      spectre's 1.25 scale) — add a `P14E` case to
      `modules/home-manager/desktop/sway/swaylock.nix` once you've picked a
      scale that feels right in the actual session
- [ ] Bluetooth: default is `powerOnBoot = mkDefault false` (laptop default)
      — override in `hosts/P14E/configuration.nix` only if you want an
      always-on radio like intelNuc
