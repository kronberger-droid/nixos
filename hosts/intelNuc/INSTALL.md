# intelNuc install checklist

Disk layout is declarative (`modules/system/boot/disk-layout.nix`), so there is
no manual partitioning and no UUIDs to copy back. This config only boots on a
disk that disko has formatted: do not rebuild the old install from it.

## Before wiping
- [ ] Push or bundle local-only git branches; copy what is not in git or
      Syncthing (Steam library and saves, `~/Public`, gitignored datasets)
- [ ] Save the machine identity, to an encrypted disk on another host:
      `/etc/ssh/ssh_host_*`, `/var/lib/tailscale/`, `~/.ssh/`,
      `~/.local/state/syncthing/{cert,key}.pem`

## Partition & install (from the recovery stick)
- [ ] Boot the stick, connect network
- [ ] `sudo disko --mode destroy,format,mount --flake /nixos-config#intelNuc`
      and set the LUKS passphrase when asked
- [ ] Restore the SSH host keys to `/mnt/etc/ssh/` (`ssh_host_ed25519_key`
      mode 600, root:root) **before** installing. agenix decrypts with this
      key and the login password is an agenix secret, so without it the first
      boot has no usable account. sshd only generates keys that are missing.
- [ ] Restore `/mnt/var/lib/tailscale/` to keep the tailnet IP that
      `modules/shared/syncthing-devices.nix` hardcodes
- [ ] `sudo nixos-install --flake /nixos-config#intelNuc`

## First boot
- [ ] Restore `~/.ssh/` and the Syncthing `cert.pem`/`key.pem` before
      Syncthing first starts, or it mints a new device ID
- [ ] `systemctl hibernate` once, to confirm resume from `/dev/pool/swap`
- [ ] Restore the Steam library with Steam closed, then start it

## If the host key was lost
- [ ] Put the new `/etc/ssh/ssh_host_ed25519_key.pub` into `secrets/secrets.nix`
      and run `agenix -r` on spectre or P14E, which hold escrow for every secret
