
## This session runs in the sandbox

You are the `claude` unix account, a separate uid from mine
(`security.agentSandbox` in my nixos config). The boundary is the point: my
home, `/home/kronberger`, is closed to you, and a permission error there is the
design working. Work from what this account holds.

- **Repos** live in `~/src/<repo>`, cloned from my fork over https:
  `gh repo clone kronberger-droid/<repo>` makes that `origin` and adds the
  parent (`nushell/nushell`, `nushell/reedline`, ...) as `upstream`. Branch off
  `upstream`, push to `origin`. `GH_TOKEN` is a fine-grained token on my
  account, granted repo by repo: it reads public upstreams but writes only to
  my repos, and a 403 or "not found" on one of mine means it isn't granted yet.
  Tell me which repo to add.
- **Handing work back** means a commit on a branch in `~/src/<repo>`, reported
  to me as path plus branch. I fetch from that path as a local remote and
  review, so work left uncommitted never reaches me. Pushes and PRs still go
  through "Outward-facing actions".
- **ssh** uses this account's own key, `~/.ssh/id_ed25519`. A server trusts it
  only once I've added it there, so a refused login means that step is missing.
- **nix** builds work, but this account is not a trusted user: a flake's
  `nixConfig` substituters are ignored and uncached paths build locally. There
  is no sudo, so work on the nixos config ends at an eval check.
- **Rust** builds with the stable toolchain and a C toolchain (`cc`, `make`,
  `cmake`, `perl`, `pkg-config`) already on PATH. When a crate links a system
  library (`openssl-sys`, `libgit2-sys`, ...), use the project's
  `nix develop` if it has one, else wrap the command:
  `nix-shell -p pkg-config openssl --run 'cargo build'`. `nix-shell` runs the
  setup hooks that point `pkg-config` and the linker at the library, which
  `nix shell` skips.
- **This file** is generated too. Here the nixos config is `~/src/nixos`
  (`kronberger-droid/nixos`), and this section's source is
  `modules/home-manager/apps/claude-md-sandbox.md`, appended in
  `modules/home-manager/users/claude.nix`.

### The EdgeRouter

On the homeserver this account has an `admin` login on the EdgeRouter at
`192.168.2.1`, user `claude`, with this account's ssh key. Elsewhere there is
no login, and a refused ssh means exactly that. `admin` is the only EdgeOS
level that can change config, and it can change all of it, so the limits are
these rules:

- **Every change goes through `commit-confirm`**, never a plain `commit`:
  `configure`, the `set`/`delete` lines, `commit-confirm 10`, check the result
  from outside the router, then `confirm`. Unconfirmed, the router reverts on
  its own. That matters because this account runs on the homeserver, behind
  the router: a change that breaks routing or DNS cuts off the session that
  would have fixed it.
- **A change to the router is outward-facing** in the sense of my global
  rules. Show me the exact `set`/`delete` lines and wait for my yes before
  `commit-confirm`. Reading config (`show configuration`, `show ...`) needs no
  confirmation.
- **Afterwards refresh the snapshot** in `~/src/nixos`:
  `nu hosts/edgerouter/pull-config.nu --user claude --key ~/.ssh/id_ed25519`,
  then commit it like any other work. Check the diff for secrets first.
- `hosts/edgerouter/README.md` lists the settings that look wrong and are
  not. Read it before touching DNS, source validation, IPv6 or DPI.

The homeserver has no `GH_TOKEN` for this account (the token is not
encrypted for it), so GitHub is read-only there: public clones over https
work, pushes do not.
