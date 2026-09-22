# Installing a host from the recovery stick

The steps every fresh install shares. Each host's own `INSTALL.md` covers
what differs (partitioning, identity restore, hardware checks) and says where
it slots in. The stick's shell is sh; the installed hosts run nu.

Why the order matters: the stick has no disk of its own. Its `/`, the upper
layer of `/nix/store` and `/tmp` are all tmpfs, so anything big that is not
explicitly put on `/mnt` lands in RAM. On the intelNuc install that was an
OOM kill, then "No space left on device" with a 1T disk mounted.

## Stick

Build it from the branch you are about to install, so `/nixos-config` on the
stick carries the current config:

```nu
nix build .#recovery -o result-recovery
udisksctl unmount -b /dev/sdX1
sudo dd if=(glob result-recovery/iso/*.iso | first) of=/dev/sdX bs=4M status=progress oflag=sync
```

## Install

1. [ ] Boot the stick, connect the network (`nmtui`), note the IP from `ip a`.
2. [ ] `sudo tailscale up` and open the login URL it prints. This puts the
       homeserver cache in reach, which holds the overlay builds (rio, niri,
       nushell) the public caches miss. Skipping it means compiling those
       on the stick; steps 4 and 5 are what make that survivable. The node
       is ephemeral and drops off the tailnet once the stick is gone. Check
       the cache answers:
       ```sh
       curl -s http://100.92.46.97:5001/nix-cache-info
       ```
3. [ ] Partition and mount under `/mnt`: the host's checklist says how
       (disko, or by hand).
4. [ ] Swap. A disko swap LV is created but not activated:
       ```sh
       sudo swapon /dev/pool/swap     # "read swap header failed": mkswap it first
       swapon --show
       ```
       The laptops (`profiles/secureboot-laptop.nix`) declare a 16G
       `/swapfile` instead. Create it now and it serves the install too;
       NixOS adopts an existing one of the right size:
       ```sh
       sudo fallocate -l 16G /mnt/swapfile && sudo chmod 600 /mnt/swapfile
       sudo mkswap /mnt/swapfile && sudo swapon /mnt/swapfile
       ```
5. [ ] Put the build directories on the disk. Builds land in the stick's own
       `/nix/var/nix/builds`, on the RAM-backed `/`, whatever `TMPDIR` says.
       A bind mount holds whichever path Nix picks:
       ```sh
       for d in /nix/var/nix/builds /tmp; do
         sudo mkdir -p "/mnt/scratch$d" "$d"
         sudo mount --bind "/mnt/scratch$d" "$d"
       done
       findmnt /nix/var/nix/builds; findmnt /tmp    # both on the target disk
       ```
6. [ ] Host-specific pre-install steps, e.g. restoring the host key, which
       has to be in `/mnt/etc/ssh` before the first boot or agenix decrypts
       nothing.
7. [ ] Install:
       ```sh
       sudo nixos-install --flake /nixos-config#<host> --max-jobs 1 --cores 8 --no-root-passwd
       ```
       The host's `max-jobs`/`cores` only apply once it runs; the installer
       defaults to every thread for every job. `--no-root-passwd` since
       userborn only creates accounts at boot: the root password prompt at
       the end fails with "cannot determine your username" otherwise, after
       the install is already complete. Logins come from agenix, not root.
8. [ ] Drop the scratch space, so it does not ship with the new root:
       ```sh
       sudo umount /nix/var/nix/builds /tmp
       sudo rm -rf /mnt/scratch
       ```
       A swapfile from step 4 stays: it is the one the host declares.

## First boot

- There is no Wi-Fi until someone logs in at the machine and connects:
  NetworkManager profiles are not part of the config. Ethernet comes up on
  its own, and tailscale with it.
- rbw: a host with `secrets/rbw-device-id-<host>.age` comes up as the
  device Bitwarden already knows, so `rbw login` and `rbw sync` are all it
  takes. A host without one registers once, then stores its ID so it never
  has to again:
  ```nu
  rbw register     # API key client_id + secret: web vault, Security > Keys
  cd ~/.config/nixos/secrets    # agenix reads ./secrets.nix
  open ~/.local/share/rbw/device_id | agenix -e rbw-device-id-<host>.age
  ```
  Then `git add` it and rebuild: the plain file is swapped for the link
  (home-manager keeps the old one as a backup).
  The recipients are already in `secrets/secrets.nix` for the three
  workstations; a new host needs its line there first.
- If the `kronberger` login fails, check `systemctl status
  decrypt-user-password`: userborn creates the account from the hash it
  writes, and skips the account if it is missing.
