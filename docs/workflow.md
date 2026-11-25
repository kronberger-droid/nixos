# Workflow

Changing the config and getting the change onto a machine. The checkout can
sit anywhere: nothing in the config names its path, and `flake` remembers the
one it last switched from. The examples here use `~/.config/nixos`.

## The loop

```nu
cd ~/.config/nixos
# edit
git add -A                # a flake only sees files git knows about
nix flake check           # every host evaluates, formatting, .nu parsing
flake                     # switch this machine
```

`flake` warns and asks when there are unstaged or untracked files, since a new
file that is not staged does not exist as far as the build is concerned.

## Checking a change

| Command | Checks |
|---------|--------|
| `nix flake check` | Everything: each host evaluates (`eval-<host>`), alejandra, `.nu` parsing, deploy-rs, and the VM tests in `tests/` |
| `nix build --no-link .#checks.x86_64-linux.eval-<host>` | One host evaluates |
| `nix fmt -- .` | Fixes formatting. The `-- .` is required; a bare `nix fmt` reads stdin and dies. |
| `flake dry` | What a switch would build, without building |
| `flake build` | Builds this host's generation without activating it |

`.githooks/pre-commit` runs the format and parse checks on staged files. It is
wired through `core.hooksPath`, which lives in `.git/config`, so a fresh clone
needs `git config core.hooksPath .githooks` once.

## Switching a workstation

`flake` is a Nushell command defined in
`modules/home-manager/shell/nushell.nix`. It wraps `nh`, which shows a package
diff before activating.

| Command | Does |
|---------|------|
| `flake` | `switch`: build and activate now |
| `flake boot` | Activate on next boot |
| `flake test` | Activate without adding a boot entry |
| `flake -u` | Update all inputs first, then switch |
| `flake update` | Update inputs only |
| `flake -r` | Build on the homeserver, then pull the result from its cache and activate here |
| `flake rollback` | Back to the previous generation |
| `flake init <template>` | Scaffold a project from `templates/`; without a name it lists them |

`flake -r` copies the staged tree and every locked input to the homeserver's
`nix-remote` account, builds this host's system there, and leaves a GC root
under that account so the build survives until it is pulled. Worth it on the
laptops for anything that compiles; it needs the tailnet end to end.

## Live config files

Everything in `live/` takes effect on save, with no switch: the helix theme,
ignore list, spelling dictionary and rumdl rules, and the yazi flavor. A file
outside `live/` needs a switch.

Programs reach those files through one link, `~/.config/nixos-live`, which
points at `<checkout>/live`. `flake switch`, `boot` and `test` point it at the
checkout they ran from, and `flake` without `--dir` reads it back to find that
checkout. So after moving the checkout, run `flake` once from inside it, or
with `--dir <new path>`.

Where no checkout holds the link (a fresh install, a deleted checkout, the
droid), activation points it at the store copy of `live/`. The files then
match the last switch and are read-only. `modules/home-manager/live-config.nix`
has the details.

## Deploying the homeserver

From any workstation:

```nu
cd ~/.config/nixos
deploy .#homeserver
```

deploy-rs builds locally, uploads over ssh as `kronberger`, activates through
sudo, and then waits up to 60 seconds for a confirmation over a fresh
connection. If that does not arrive, or a unit fails during activation, it
rolls the server back by itself. That is the safety net for a change that
breaks sshd, the firewall or Tailscale.

Things that have caused a rollback for the wrong reason:

- A unit that fails once during the switch and would have recovered. The
  agenix start race on tuwunel and radicale was this.
- A change that restarts Tailscale on the target. The deploy goes through
  MagicDNS, so the confirmation loses its channel. Deploy to
  `100.92.46.97` instead by overriding the hostname:
  `deploy .#homeserver --hostname 100.92.46.97`.

To see what is deployed: `ssh homeserver nixos-version --configuration-revision`.

## Rolling back

| Machine | How |
|---------|-----|
| Workstation, still boots | `flake rollback` |
| Workstation, does not boot | Pick an older generation in the boot menu |
| Homeserver | Usually automatic. By hand: `ssh homeserver sudo nixos-rebuild switch --rollback`, or deploy an older commit |
| Nothing boots | The recovery stick, `nix build .#recovery`, see `hosts/recovery/INSTALL.md` |

## Updating inputs

The homeserver does this every night at 03:30
(`modules/system/services/flake-autoupdate.nix`). It updates the lock, builds
all four NixOS hosts, and opens a PR on `auto/flake-update` whose body lists
what moved, notable version bumps, the CVE delta and which pins can go.
Because the build ran on the server, merging and then switching mostly
downloads from its cache.

By hand:

```nu
nix flake update                  # everything
nix flake update nushell-src      # one input
flake -u                          # everything, then switch
```

Several inputs are pinned on purpose, each with a comment in `flake.nix`
saying what has to happen before the pin can go.

## Secrets

agenix. Encrypted files in `secrets/`, the recipients of each in
`secrets/secrets.nix`, decrypted at activation to `/run/secrets/<name>` with
the host's ssh host key.

Each secret is readable by the hosts that use it plus the editor, which is
intelNuc's host key. So editing happens on intelNuc, as root:

```nu
cd ~/.config/nixos/secrets
sudo agenix -e <name>.age -i /etc/ssh/ssh_host_ed25519_key
```

Adding a secret:

1. Add a line to `secrets/secrets.nix` naming who may read it.
2. Create it with the command above. The comment beside each entry says what
   the file should contain.
3. Declare it under `age.secrets` where it is used.
   `modules/system/security/agenix.nix` holds the workstation ones, the
   homeserver's are in its own files.
4. `git add` the `.age` file, or the flake will not see it.

After changing who may read a secret, re-encrypt: `sudo agenix -r -i
/etc/ssh/ssh_host_ed25519_key`, again on intelNuc.

Several secrets are gated on the file existing (`builtins.pathExists`), so
the config evaluates before the secret is made and the feature turns on when
the file appears. The Mullvad keys, the restic set and the TISS URL work this
way.

## Adding a host

1. `hosts/<name>/configuration.nix` and `hardware-configuration.nix`.
   Workstations import `../common.nix` and whichever of
   `modules/profiles/` apply.
2. An entry in `nixosConfigurations` in `flake.nix`, through `mkHost`.
3. Its ssh host key in `modules/shared/host-keys.nix`, its user key in
   `modules/shared/ssh-keys.nix`, its Syncthing ID in
   `modules/shared/syncthing-devices.nix`.
4. Add it to the recipients in `secrets/secrets.nix` and re-key on intelNuc.
5. Install from the recovery stick, `hosts/recovery/INSTALL.md`.

## Where things live

| Looking for | Path |
|-------------|------|
| A host's own settings | `hosts/<name>/configuration.nix` |
| What all workstations share | `hosts/common.nix`, then `modules/system/` |
| Laptop and VPN bundles | `modules/profiles/` |
| Server services | `modules/system/services/` |
| Desktop: niri, bar, launcher | `modules/home-manager/desktop/` |
| Shell, the `flake` command, git | `modules/home-manager/shell/` |
| Config files editable without a switch | `live/` |
| Apps and their sandboxes | `modules/home-manager/apps/` |
| Claude Code settings, global CLAUDE.md, skills | `modules/home-manager/apps/claude*.nix`, `claude-md*.md`, `skills/` |
| Addresses, keys and IDs used by more than one host | `modules/shared/` |
| Overlays and pinned packages | `flake.nix`, `modules/shared/*-overlay.nix` |
