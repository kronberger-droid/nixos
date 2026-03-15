# Impermanence Install Guide

Step-by-step guide for installing NixOS with btrfs impermanence on spectre or intelNuc.
Boot from a minimal NixOS USB stick and follow these steps.

## 1. Identify your disk

```sh
lsblk
```

Find your NVMe/SSD — typically `/dev/nvme0n1` or `/dev/sda`.
The examples below use `/dev/nvme0n1`. Adjust accordingly.

## 2. Partition the disk

```sh
sudo parted /dev/nvme0n1 -- mklabel gpt
sudo parted /dev/nvme0n1 -- mkpart ESP fat32 1MiB 512MiB
sudo parted /dev/nvme0n1 -- set 1 esp on
sudo parted /dev/nvme0n1 -- mkpart swap linux-swap 512MiB 8GiB
sudo parted /dev/nvme0n1 -- mkpart root btrfs 8GiB 100%
```

Adjust swap size to your needs (match RAM size if you want hibernate).

## 3. Format partitions

```sh
sudo mkfs.fat -F 32 /dev/nvme0n1p1
sudo mkswap /dev/nvme0n1p2
sudo mkfs.btrfs -f /dev/nvme0n1p3
```

## 4. Create btrfs subvolumes

```sh
sudo mount /dev/nvme0n1p3 /mnt
sudo btrfs subvolume create /mnt/@root
sudo btrfs subvolume create /mnt/@nix
sudo btrfs subvolume create /mnt/@persist
sudo btrfs subvolume create /mnt/@home
sudo umount /mnt
```

## Pre-install: Backup SSH and host keys (BEFORE wiping the disk)

Do this on the **running system** before booting the installer.
This preserves your host identity so agenix secrets remain decryptable.

```sh
# Plug in a USB stick, find it:
lsblk

# Mount it (adjust device name):
sudo mount /dev/sdX1 /mnt/usb

# Backup host keys
sudo mkdir -p /mnt/usb/spectre-keys/host
sudo cp /etc/ssh/ssh_host_* /mnt/usb/spectre-keys/host/

# Backup user SSH keys
cp -r ~/.ssh /mnt/usb/spectre-keys/user-ssh

sudo umount /mnt/usb
```

Eject the USB and keep it safe. You will need it in step 6.

---

## 5. Mount everything

```sh
sudo mount -o subvol=@root,compress=zstd,noatime /dev/nvme0n1p3 /mnt

sudo mkdir -p /mnt/{boot,nix,home}
sudo mount /dev/nvme0n1p1 /mnt/boot
sudo mount -o subvol=@nix,compress=zstd,noatime /dev/nvme0n1p3 /mnt/nix

sudo mkdir -p /mnt/nix/persist
sudo mount -o subvol=@persist,compress=zstd,noatime /dev/nvme0n1p3 /mnt/nix/persist

sudo mount -o subvol=@home,compress=zstd,noatime /dev/nvme0n1p3 /mnt/home

sudo swapon /dev/nvme0n1p2
```

## 6. Generate config

```sh
sudo nixos-generate-config --root /mnt
```

This creates `/mnt/etc/nixos/hardware-configuration.nix` with the correct
UUIDs and btrfs subvolume mounts auto-detected.

## 7. Patch the generated hardware-configuration.nix

Two things `nixos-generate-config` won't set for you:

### a) Add `neededForBoot = true`

Edit `/mnt/etc/nixos/hardware-configuration.nix` and add `neededForBoot = true;`
to the `/nix`, `/nix/persist`, and `/home` mounts:

```nix
fileSystems."/nix" = {
  # ... (auto-generated device, fsType, options)
  neededForBoot = true;
};

fileSystems."/nix/persist" = {
  # ... (auto-generated)
  neededForBoot = true;
};

fileSystems."/home" = {
  # ... (auto-generated)
  neededForBoot = true;
};
```

### b) Add the root wipe script

Add this to the same file (or to the host's `configuration.nix`):

```nix
boot.initrd.postResumeCommands = lib.mkAfter ''
  mkdir -p /mnt
  mount -o subvol=/ /dev/disk/by-uuid/<BTRFS-UUID> /mnt
  btrfs subvolume delete /mnt/@root
  btrfs subvolume create /mnt/@root
  umount /mnt
'';
```

Replace `<BTRFS-UUID>` with the UUID from the generated config
(the one used for the `/` mount).

## 8. Clone and link this config

```sh
sudo nix-shell -p git
cd /mnt/home/kronberger  # or wherever you want it
git clone https://github.com/<your-repo>/nixos.git .config/nixos
```

Now copy the generated `hardware-configuration.nix` into the repo:

```sh
cp /mnt/etc/nixos/hardware-configuration.nix \
   /mnt/home/kronberger/.config/nixos/hosts/<hostname>/hardware-configuration.nix
```

## 9. Impermanence is already enabled for spectre

The flake already imports `impermanence.nix` for spectre via `extraModules`.
No changes needed here. When you're ready for intelNuc, add the same line
to its host definition in `flake.nix`:

```nix
intelNuc = mkHost {
  hostname = "intelNuc";
  system = x86System;
  isNotebook = false;
  extraModules = [./modules/system/impermanence.nix];
};
```

## 10. Restore SSH and host keys from backup

Mount your USB stick with the backed-up keys and restore them into the
persist subvolume. This ensures agenix can decrypt all secrets on first boot
and your personal SSH keys (GitHub, servers, etc.) are already in place.

```sh
# Mount the USB stick
mount /dev/sdX1 /mnt/usb

# Restore host keys into persist
mkdir -p /mnt/nix/persist/etc/ssh
cp /mnt/usb/spectre-keys/host/* /mnt/nix/persist/etc/ssh/
chmod 600 /mnt/nix/persist/etc/ssh/ssh_host_*_key
chmod 644 /mnt/nix/persist/etc/ssh/ssh_host_*_key.pub

# Restore user SSH keys into persist
mkdir -p /mnt/nix/persist/home/kronberger/.ssh
cp -r /mnt/usb/spectre-keys/user-ssh/* /mnt/nix/persist/home/kronberger/.ssh/
chmod 700 /mnt/nix/persist/home/kronberger/.ssh
chmod 600 /mnt/nix/persist/home/kronberger/.ssh/id_*

umount /mnt/usb
```

If you did NOT back up the old keys, the install will generate new host keys.
In that case you must update `secrets/secrets.nix` with the new public key
and re-encrypt all secrets:

```sh
cat /mnt/etc/ssh/ssh_host_ed25519_key.pub
# Update the spectre key in secrets/secrets.nix, then:
cd /mnt/home/kronberger/.config/nixos/secrets
agenix -r
```

## 11. Install

Point the installer at your flake:

```sh
sudo nixos-install --flake /mnt/home/kronberger/.config/nixos#<hostname>
```

Where `<hostname>` is `spectre` or `intelNuc`.

## 12. Reboot and verify

After reboot, verify impermanence is working:

```sh
# This file should NOT survive a reboot
touch /test-ephemeral

# These should survive
ls /nix/persist
ls /home/kronberger/Documents
```

Reboot again and check that `/test-ephemeral` is gone.

## Troubleshooting

- **Can't log in**: The password hash from agenix may not have decrypted.
  Boot the installer USB, mount partitions, and check
  `/mnt/nix/persist/etc/ssh/` has the host keys that match `secrets.nix`.
- **Boot fails at mount**: Check that `neededForBoot = true` is set on
  `/nix`, `/nix/persist`, and `/home`.
- **Services lost state**: Check if the service's data directory is listed
  in `modules/system/impermanence.nix`. Add it and rebuild.
