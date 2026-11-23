# Access

Who can log in where, with which key, and what the address is.

Everything here assumes the tailnet is up. SSH on the workstations and nearly
every service on the homeserver listen on `tailscale0` only, so "connection
refused" or a hang usually means Tailscale is down on one end, not that the
service is.

## Homeserver

```nu
ssh homeserver                                  # interactive, lands in nu
ssh homeserver systemctl status tuwunel         # one command, runs in bash
ssh kronberger@192.168.2.54                     # from the LAN, without the tailnet
```

`homeserver` resolves through MagicDNS. The login shell is bash on purpose, so
commands sent over ssh are POSIX sh; an interactive login execs into nu.

From intelNuc every login to the homeserver signs with the admin key,
`~/.ssh/id_ed25519_admin`, straight from disk and never through the agent. It
has a passphrase. A control master keeps the connection for two minutes, so a
deploy's several connections ask once. The laptops have no admin key yet and
use their everyday key (`modules/shared/ssh-admin-keys.nix` explains the
split and how to make one).

Accounts on the box (`hosts/homeserver/configuration.nix`):

| Account | For | Who gets in | Power |
|---------|-----|-------------|-------|
| `kronberger` | Administration, deploy-rs | Workstation keys; intelNuc with the admin key only | `wheel`, passwordless sudo |
| `nix-remote` | Remote builds, `flake -r`, the phone's builder | Workstation keys, workstation host keys and the phone key, the last two store-only | Trusted Nix user, no sudo. Still root-equivalent through the daemon. |
| `droid` | The phone | The phone's key | May run `claude-sandbox-open`, `claude-sandbox-close` and `claude-sandbox-grant` through sudo, nothing else |
| `wiesinger` | His container deployments | His two keys | `docker` group |
| `claude` | Claude Code sandbox | Nobody over ssh. `ssh -t homeserver claude-sandbox` | No sudo, no password |

Root login is off everywhere, and so is password authentication
(`modules/system/security/hardening.nix`).

## Workstations

```nu
ssh intelNuc
ssh spectre
ssh P14E
```

User `kronberger`, any workstation's everyday key
(`modules/shared/ssh-keys.nix`), port 22 on `tailscale0` only. A new machine
gets in everywhere once its public key is added to that file and the hosts
are switched.

The phone has its own key and is deliberately not in that set. It reaches the
homeserver's `droid` and `nix-remote` accounts and nothing else.

## Matrix and the WhatsApp bridge

There are two different things to get into: the Matrix account, which is what
you chat through, and the server process behind it.

**The account.** Any Matrix client, on the tailnet:

| Field | Value |
|-------|-------|
| Homeserver URL | `https://homeserver.tailc7340c.ts.net` |
| Username | `kronberger` |
| Full Matrix ID | `@kronberger:kron-berger.com` |

Log in with the server URL and the bare username. Entering the Matrix ID
alone does not work: `kron-berger.com` publishes no
`/.well-known/matrix/client`, because doing so would put the tailnet hostname
on the public site. Element desktop on the workstations is already pointed at
the server by `modules/home-manager/apps/element.nix`. On the phone use
Element classic with a custom server; Element X is untested against tuwunel.

The password is not in this repo. tuwunel generated one when it created the
account and printed it to its journal once; it was changed after the first
login. If it is lost while a session is still logged in, reset it from the
admin room (`#admins:kron-berger.com`) with
`!admin users reset-password kronberger`; `!admin users --help` shows the
exact form for the running version. With no session left, the same command
can go through the config: add `"users reset-password kronberger"` to
`admin_execute` in `modules/system/services/matrix.nix`, deploy, read the new
password from `journalctl -u tuwunel`, then take the line out again. Neither
path has been exercised on this server yet.

**The WhatsApp side.** WhatsApp chats show up as ordinary rooms. The bridge is
a linked device on the WhatsApp account, so:

- The phone has to come online at least every two weeks or WhatsApp unlinks
  the bridge.
- To link again, open the direct chat with the bridge bot
  (`@whatsappbot:kron-berger.com`) and send `login qr`, then scan the code
  with WhatsApp on the phone under Linked devices. `help` lists the rest.

**The server.** Both daemons run on the homeserver, see
[homeserver.md](homeserver.md#matrix-and-whatsapp) for units, logs and data.

## The Claude sandbox

Claude Code never runs as `kronberger`. It runs as the `claude` account, a
separate uid with its own home, on every host
(`modules/system/security/agent-sandbox.nix`).

| Command | Where | Does |
|---------|-------|------|
| `claude` | workstation | Opens Claude Code in the sandbox, in its checkout of the repo you are standing in. Clones it after asking if there is none. |
| `claude-sandbox` | any host | A shell as the sandbox account. With arguments, runs that command there. |
| `ssh -t homeserver claude-sandbox` | anywhere | The same on the homeserver. |
| `ssh homeserver claude-sandbox-open 3h` | anywhere, phone included | Opens a Remote Control window so claude.ai can spawn sessions on the homeserver. Default 2h, at most 12h. |
| `ssh homeserver claude-sandbox-close` | anywhere | Ends the window early. |
| `git fetch-sandbox` | in your checkout | Fetches the `sandbox` remote, which `claude` keeps pointed at the sandbox's checkout of the same repo. Review, then push with your own key. |
| `claude-sandbox-grant list` | any host | Shows what the sandbox has been lent and what it is asking for. Also `approve [id]`, `deny [id]`, `revoke <name>`, `reset`. |

What the sandbox can touch:

- Its own home, `/home/claude`. You can read it; it cannot read yours.
- `~/Projects` and `~/.config/nixos`, read-only.
- The vault, read and write, mounted at the same path under its home.
- GitHub through a fine-grained token scoped repo by repo. A push that fails
  with 403 on one of your repos means the token has not been granted that
  repo yet.
- Anything else only by asking. It runs `claude-sandbox-request <path>`, you
  approve (a password prompt on the workstations, `claude-sandbox-grant
  approve` on the homeserver), and the path appears read-only under
  `/run/claude-sandbox-grants` for the span. Keys, tokens and browser
  profiles are never granted. While a grant is open the sandbox can copy all
  of it, so approving means it may have all of it.

## EdgeRouter

| What | Value |
|------|-------|
| Address | `192.168.2.1` |
| Web UI | `https://192.168.2.1` |
| SSH | `ssh -i ~/.ssh/edgerouter/kronberger kronberger@192.168.2.1`, keys only |

Reachable from the LAN, and from any tailnet device through the homeserver's
subnet route. The router itself cannot run Tailscale.

After changing anything on it, refresh the snapshot and read the diff before
committing, since the repo is public:

```nu
nu hosts/edgerouter/pull-config.nu
```

Use `commit-confirm 10` on the router rather than `commit` when the change
touches routing, DNS or the firewall. Unconfirmed, it reverts by itself, and
a session that came in through the homeserver would otherwise have cut off
its own way back.

## Clusters

Plain `ssh_config` hosts from `modules/home-manager/users/kronberger.nix`, so
`scp`, `rsync` and git use them too.

| Alias | Host | User |
|-------|------|------|
| `datalab` | `cluster.datalab.tuwien.ac.at` | `martin.kronberger` |
| `asc4` | `vsc4.vsc.ac.at` | `sumo_mk` |
| `asc5` | `vsc5.vsc.ac.at` | `sumo_mk` |
