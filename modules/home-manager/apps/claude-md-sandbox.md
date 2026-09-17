
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
- **This file** is generated too. Here the nixos config is `~/src/nixos`
  (`kronberger-droid/nixos`), and this section's source is
  `modules/home-manager/apps/claude-md-sandbox.md`, appended in
  `modules/home-manager/users/claude.nix`.
