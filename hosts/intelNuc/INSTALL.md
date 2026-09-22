# intelNuc install checklist

Disk layout is declarative (`modules/system/boot/disk-layout.nix`), so there is
no manual partitioning and no UUIDs to copy back. This config only boots on a
disk that disko has formatted: do not rebuild the old install from it.

Shells: the old intelNuc and P14E run nu as the login shell, so commands there
are nu and anything after `ssh P14E` is parsed by nu (no `>` redirects). The
live stick is a stock installer, its commands are sh.

## Before wiping (on the old intelNuc, nu)

- [ ] Push or bundle local-only git branches, or just take all of Projects:
      `rsync -aH --exclude target --exclude node_modules ~/Projects $"($dst)/"`
- [ ] Bulk data to the external disk (`$dst` = its mount point):
      ```nu
      rsync -aH --info=progress2 --exclude steamapps/shadercache --exclude logs ~/.local/share/Steam $"($dst)/"
      rsync -aH ~/.local/share/Terraria ~/.local/share/irrationalgames ~/.local/share/PrismLauncher ~/.config/unity3d ~/Public $"($dst)/"
      ```
      Native Linux games save in `~/.local/share` and `~/.config`, Proton
      games inside `steamapps/compatdata/<appid>/pfx`, which the first line
      covers. `appmanifest_*.acf` must come along or Steam re-downloads.
- [ ] Machine identity, to P14E rather than the external disk, since the
      host key decrypts every agenix secret. Tar locally, then `scp`; a
      remote `cat > file` would run in nu and fail:
      ```nu
      let tmp = (mktemp -d)
      sudo tar -C / -czf $"($tmp)/intelNuc-identity.tgz" etc/ssh var/lib/tailscale
      tar -C ~ -czf $"($tmp)/intelNuc-user-identity.tgz" .ssh .local/state/syncthing/cert.pem .local/state/syncthing/key.pem
      scp $"($tmp)/intelNuc-identity.tgz" $"($tmp)/intelNuc-user-identity.tgz" P14E:
      ssh P14E "ls intelNuc-*.tgz; tar -tzf intelNuc-user-identity.tgz | lines"
      ```
      What each file pins: the host key is intelNuc's recipient in
      `secrets/secrets.nix`; `~/.ssh/id_ed25519` is in `modules/shared/ssh-keys.nix`
      and on GitHub; the Syncthing cert is the device ID and
      `/var/lib/tailscale` the tailnet IP, both in
      `modules/shared/syncthing-devices.nix`. Transferring them means the
      config does not change at all. There are no Secure Boot keys to save,
      they are generated on the new install.
- [ ] Merge the disko branch, then build and flash the stick from it, so
      `/nixos-config` on the stick carries this layout:
      ```nu
      nix build .#recovery -o result-recovery
      udisksctl unmount -b /dev/sdX1
      sudo dd if=(glob result-recovery/iso/*.iso | first) of=/dev/sdX bs=4M status=progress oflag=sync
      ```
      From that merge on, do not `nixos-rebuild` the old install.

## Partition & install (on the live stick, sh)

- [ ] Boot the stick, connect network, note the IP from `ip a`
- [ ] `sudo disko --mode destroy,format,mount --flake /nixos-config#intelNuc`
      and set the LUKS passphrase when asked
- [ ] Bring the identity back. The stick has no key P14E would accept, so
      push from P14E; the stick's sshd accepts the workstation keys:
      ```nu
      # on P14E
      scp intelNuc-identity.tgz intelNuc-user-identity.tgz root@<live-ip>:
      ```
      ```sh
      # on the stick
      tar -C /mnt -xzf ~/intelNuc-identity.tgz etc/ssh var/lib/tailscale
      ls -l /mnt/etc/ssh/ssh_host_ed25519_key     # 600 root:root
      ```
      This has to happen **before** installing: agenix decrypts with this
      key and the login password is an agenix secret, so without it the first
      boot has no usable account. sshd only generates keys that are missing.
- [ ] Turn on swap. disko creates the LV but does not activate it, and the
      Rust builds OOM-kill the install on 16G without it:
      ```sh
      sudo swapon /dev/pool/swap     # "read swap header failed": mkswap it first
      swapon --show                  # ~20G
      ```
- [ ] Put the build directories on the disk. Builds land in the live
      system's `/nix/var/nix/builds`, on the RAM-backed `/`, whatever
      `TMPDIR` says, and rio's `target/` fills it ("No space left on
      device" on a 1T disk). A bind mount holds whichever path Nix picks:
      ```sh
      for d in /nix/var/nix/builds /tmp; do
        sudo mkdir -p "/mnt/scratch$d" "$d"
        sudo mount --bind "/mnt/scratch$d" "$d"
      done
      findmnt /nix/var/nix/builds; findmnt /tmp    # both on pool-root
      ```
- [ ] `sudo nixos-install --flake /nixos-config#intelNuc --max-jobs 1 --cores 8`
      The host's `max-jobs`/`cores` only apply once it runs; the installer
      defaults to every thread for every job.
- [ ] Drop the scratch space, so it does not ship with the new root:
      `sudo umount /nix/var/nix/builds /tmp; sudo rm -rf /mnt/scratch`
- [ ] Keep the user tarball for after first boot:
      `cp ~/intelNuc-user-identity.tgz /mnt/root/`

## First boot

- [ ] Before Syncthing first runs, or it mints a new device ID:
      `sudo tar -C ~ -xzf /root/intelNuc-user-identity.tgz` then
      `sudo chown -R kronberger:users ~/.ssh ~/.local/state/syncthing`
- [ ] `systemctl hibernate` once, to confirm resume from `/dev/pool/swap`
- [ ] Restore the Steam library and saves from the external disk with Steam
      closed, same paths as backed up, then start it

## Secure Boot + TPM2 (lanzaboote)

The install goes through unsigned and the first boot asks for the passphrase;
`generate-sb-keys.service` creates the keys in `/var/lib/sbctl` on that boot.
The order below matters: the TPM seals against PCR 7, the Secure Boot state.
- [ ] Rebuild once (`nixos-rebuild switch`), so lanzaboote signs with the new
      keys; `sbctl verify` should list everything as signed
- [ ] Reboot into firmware setup, put Secure Boot into Setup Mode
- [ ] `sudo sbctl enroll-keys -m`
- [ ] Reboot into firmware setup, enable Secure Boot; `sbctl status` after
      boot should say enabled, user mode
- [ ] Only now:
      `sudo systemd-cryptenroll --tpm2-device=auto /dev/disk/by-partlabel/disk-main-luks`
      Done earlier it seals against the Secure-Boot-off PCR 7 and stops
      unlocking once Secure Boot is on. That fails safe, to the passphrase
      prompt, but has to be redone.
- [ ] Reboot: no passphrase prompt. Keep the passphrase, it is the fallback
      after firmware updates change PCR 7.

## If the host key was lost

- [ ] Put the new `/etc/ssh/ssh_host_ed25519_key.pub` into `secrets/secrets.nix`
      and run `agenix -r` on spectre or P14E, which hold escrow for every secret
