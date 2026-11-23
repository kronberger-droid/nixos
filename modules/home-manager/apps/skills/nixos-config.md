---
name: nixos-config
description: Work on Martin's NixOS flake. Which hosts a change reaches, and the cheapest check that proves it.
when_to_use: >-
  Before editing or checking anything in the nixos config (`~/.config/nixos`,
  `~/Projects/other/nixos` in the sandbox), from whichever repo the session
  started in. Also before running `nix flake check`, `nix build` or a host
  evaluation there.
user-invocable: true
---

# NixOS config

`README.md` in the repo has the host table and the directory tree. This skill
holds what the tree does not say: how far a change reaches and how much
checking that reach is worth.

## Reach

A change's **reach** is the set of hosts whose evaluation includes the file.
Work it out before checking anything, since it picks the check. Follow the
imports up from the file you changed until you hit one of these roots:

| Root | Hosts |
|------|-------|
| `hosts/<name>/configuration.nix` | that host |
| `hosts/common.nix`, `modules/home-manager/users/kronberger.nix` | the workstations: `intelNuc`, `spectre`, `P14E` |
| `modules/home-manager/users/kronberger-server.nix` | `homeserver` |
| `modules/home-manager/users/claude.nix` | the sandbox account, on every host that enables `security.agentSandbox` |
| `hosts/droid/home.nix` | `droid` |
| `flake.nix`, `flake.lock`, `modules/shared/` | everything |

The server and droid import shared modules one by one instead of taking the
whole tree, so a file under `modules/home-manager/` reaches them only where
one of their roots names it.

`droid` is a nix-on-droid configuration, outside `nixosConfigurations`, thus
outside every `eval-<host>` check and outside `nix flake check`. When the
reach includes it, say in the handover that droid was not checked.

## The check ladder

Climb to the lowest rung that covers the reach, stop there, and name the rung
in the handover. Stage first on every rung: a flake only sees files git knows,
so a new file that is not staged does not exist to nix.

1. **Format and parse.** `nix fmt -- <files>` for `.nix`. `.githooks/pre-commit`
   covers `.nix` and `.nu` once the clone is wired with
   `git config core.hooksPath .githooks`. Seconds.
2. **One option.** Evaluate the value you changed, on one host of the reach:

       nix eval --raw '.#nixosConfigurations.<host>.config.home-manager.users.<user>.<option.path>'

   This proves the module evaluates and prints what it generates. When the
   value is text for another program, feed it to that program and look at the
   result. This rung is enough for a change to one module's generated output.
3. **One host per root.** One representative for each root in the reach,
   `spectre` for the workstations:

       nix build --no-link .#checks.x86_64-linux.eval-<host>

   Each takes minutes on one core. Several hosts go faster as separate
   processes than as one command. Use this rung when the change moves options
   other modules read, touches imports, or edits a host file.
4. **The full gate.** `nix flake check` evaluates every host and also builds:
   the deploy-rs checks, the VM tests in `tests/`, the format and nu-parse
   checks. It is Martin's rung before a switch. Run it only when he asks, or
   ask first when the reach is everything.

Rungs 3 and 4 are **heavy**. Before a heavy command, say what it costs and why
the rung below does not cover the change, then run it in the background and
keep working. A nix command Martin stops is his answer: carry on without it
and report the rung you reached.

In the sandbox the ladder ends at rung 3. That account has no sudo, so nothing
is switched, and it is not a trusted nix user, so the flake's substituters are
ignored and rung 4 compiles what a cache would have served.

## Theme

Colors come from `config.scheme` in `theming/base16-scheme.nix`. They reach a
program by one of two routes:

- A terminal program that prints the 16 ANSI colors follows the theme with no
  config, since the terminal resolves those slots through `theming/ansi.nix`.
- Everything else gets a generated config that interpolates the scheme:
  `config.scheme.base0D` is hex without the `#`, and `base0D-rgb-r`, `-rgb-g`,
  `-rgb-b` are the decimal channels.

A program that ignores the theme is printing 256-color indices or RGB, which
the terminal palette cannot remap. It needs the second route.

## Handing over

`git fetch origin`, then branch off `origin/main`, whatever the checkout has
checked out and wherever its local `main` points. One change per branch. Report the path, the branch, the rung reached, and any host in the
reach that went unchecked.
