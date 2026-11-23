# Homeserver

One Intel NUC, always on. LAN `192.168.2.54`, tailnet `100.92.46.97`,
MagicDNS `homeserver`. Config in `hosts/homeserver/configuration.nix` plus the
modules it imports from `modules/system/services/`.

Getting a shell is in [access.md](access.md#homeserver). Deploying is in
[workflow.md](workflow.md#deploying-the-homeserver).

## Services

"Tailnet" means the port is open on `tailscale0` only. A device without
Tailscale cannot reach it, on the LAN or anywhere else.

| Service | Unit | Port | Reach | Address to use |
|---------|------|------|-------|----------------|
| SSH | `sshd` | 22 | LAN, tailnet | `ssh homeserver` |
| DNS and ad blocking (blocky) | `blocky` | 53 | LAN, tailnet | handed out by DHCP |
| Matrix (tuwunel) | `tuwunel` | 6167, HTTPS on 443 through `tailscale serve` | tailnet | `https://homeserver.tailc7340c.ts.net` |
| WhatsApp bridge | `mautrix-whatsapp` | 29318 | loopback | none, tuwunel is its only client |
| Photos (immich) | `immich-server`, `immich-machine-learning` | 2283 | tailnet | `http://photos.home.lan:2283` |
| Contacts and calendars (radicale) | `radicale` | 5232 | tailnet | `http://homeserver:5232`, user `kronberger` |
| TISS timetable mirror | `tiss-calendar` (hourly timer) | none | none | shows up as the `tuwien` calendar in radicale |
| Zotero attachments (WebDAV) | `webdav` | 6065, HTTPS on 8443 through `tailscale serve` | tailnet | `https://homeserver.tailc7340c.ts.net:8443` for Android, the plain tailnet URL on desktops |
| Binary cache (harmonia) | `harmonia` | 5001 | tailnet | `http://100.92.46.97:5001`, set as a substituter fleet-wide |
| Website | `nginx` on 8080, `cloudflared-tunnel-<id>` | 8080 | loopback, public through the Cloudflare tunnel | `https://kron-berger.com` |
| Syncthing | `syncthing` | 22000 | tailnet | peers are declared in `modules/shared/syncthing-devices.nix` |
| Containers (docker) | `docker` | whatever is published | tailnet | wiesinger's deployments |
| Tailscale | `tailscaled` | | | subnet router for `192.168.2.0/24`, exit node through Mullvad |

## Looking after it

All of these work as `ssh homeserver <command>`.

```sh
systemctl --failed                        # anything broken?
systemctl status <unit>
journalctl -u <unit> -n 100               # recent log
journalctl -u <unit> -f                   # follow
sudo systemctl restart <unit>
systemctl list-timers                     # what runs when
nixos-version --configuration-revision    # which commit is deployed
ls /etc/nixos-source                      # the source of the running generation
```

Scheduled jobs:

| When | Unit | Does |
|------|------|------|
| every 5 min | `dns-healthcheck` | Probes blocky over loopback, tells a dead resolver from a dead uplink, restarts only the former |
| hourly | `tiss-calendar` | Mirrors the TISS timetable into radicale, one way |
| 02:30 | `postgresqlBackup-immich` | Dumps the immich database |
| 03:30 | `restic-backups-homeserver` | Ships the dump and the state directories off the box. Only exists once the three restic secrets do. |
| 03:30 | `flake-autoupdate` | Updates the inputs of this flake and two others, builds every host, opens a PR per repo on branch `auto/flake-update` |
| weekly | `docker-prune` | Removes containers and images unused for a week |

## Matrix and WhatsApp

Config: `modules/system/services/matrix.nix`. Design and traps:
[hosts/homeserver/matrix-whatsapp.md](../hosts/homeserver/matrix-whatsapp.md).
Logging in as a user: [access.md](access.md#matrix-and-the-whatsapp-bridge).

| Unit | Is |
|------|----|
| `tuwunel` | The Matrix homeserver. State in `/var/lib/tuwunel` (RocksDB). |
| `mautrix-whatsapp` | The bridge. State and WhatsApp session in `/var/lib/mautrix-whatsapp`. |
| `tailscale-serve-matrix` | Oneshot that puts tuwunel behind HTTPS on the tailnet name. |

```sh
systemctl status tuwunel mautrix-whatsapp tailscale-serve-matrix
journalctl -u mautrix-whatsapp -n 100
journalctl -u tuwunel -n 100
tailscale serve status                    # is the HTTPS front up?
```

When something is off:

- **Element cannot connect.** Check the tailnet first, then
  `tailscale serve status`. Element needs the HTTPS front; plain
  `http://homeserver:6167` only works for clients that allow it.
- **Messages stop arriving from WhatsApp.** The bridge was probably unlinked
  because the phone stayed offline for two weeks. Its log says so. Link again
  with `login qr` in the chat with the bridge bot.
- **The bridge exits with status 16 after a deploy.** tuwunel does not know
  its token. The two appservice registrations are agenix secrets that tuwunel
  reads at startup, so this means tuwunel started before agenix had installed
  them, or the registration was regenerated without re-encrypting the secret.
- **A deploy rolls back with tuwunel failing at `CREDENTIALS`.** The agenix
  start race, fixed with `wants` on `agenix-chown.service`. If it comes back,
  that ordering is where to look.

The server name `kron-berger.com` is permanent. It is part of every user and
room ID, and changing it means starting a fresh server.

## Website

Static site from the `website` flake input, served by nginx on loopback and
published through a Cloudflare tunnel. Nothing is open to the internet on
this box; cloudflared dials out.

Publishing a change:

```nu
# in the website repo: commit and push, then in ~/.config/nixos
nix flake update website
deploy .#homeserver
```

## Backups

`modules/system/services/backup.nix`. Two layers:

1. A nightly Postgres dump of the immich database, always on.
2. restic, which ships that dump plus `/var/lib/immich`, `radicale`,
   `tuwunel`, `mautrix-whatsapp` and `webdav` to an off-box repository. It
   keeps 7 daily, 5 weekly and 12 monthly snapshots and reads 2 % of the data
   back on every run.

restic only switches on once `restic-repository.age`, `restic-password.age`
and `restic-env.age` exist in `secrets/`. Until then the NVMe holds the only
copy of the photo library. Keep the repository password somewhere outside
this repo as well, or the backup cannot be read after losing both the server
and intelNuc.

```sh
sudo systemctl start restic-backups-homeserver    # run now
sudo restic-homeserver snapshots                  # what is there
sudo restic-homeserver restore latest --target /tmp/restore --include /var/lib/radicale
```

## Storage and limits

- One NVMe, `noatime`, SMART monitored by `smartd`. Journal capped at 1 GB.
- 15 GB RAM shared by Postgres, immich's ML worker, docker and remote builds.
  `earlyoom` kills the largest process before the kernel takes Postgres; the
  ML worker is capped at 6 GB. Nix builds run 4 jobs on 4 cores.
- Postgres is pinned to 17. A major upgrade is dump, bump the pin, restore;
  bumping `stateVersion` alone would start immich on an empty database.
- Sleep is disabled.
