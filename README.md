# NixOS Configuration

Personal NixOS flake configuration. This is tailored entirely to my own
machines and workflow -- it is not designed to be reusable or configurable for
others. Expect hardcoded preferences, minimal abstraction, and very few knobs
to turn.

How to use it day to day (getting into machines and services, switching,
deploying, secrets, the network) is in the [handbook](docs/README.md).

## Hosts

| Host | Arch | Description |
|------|------|-------------|
| `intelNuc` | x86_64 | Desktop |
| `spectre` | x86_64 | Laptop |
| `P14E` | x86_64 | Laptop |
| `homeserver` | x86_64 | Server: DNS, photos, CalDAV, binary cache, website |
| `droid` | aarch64 | Phone, via nix-on-droid |
| `recovery` | x86_64 | Rescue ISO, `nix build .#recovery` |
| `edgerouter` | mips | EdgeOS router; config snapshot only, not built by Nix |

## Structure

```
.
├── flake.nix              # Inputs, hosts, overlays, checks, dev shell, templates
├── hosts/                 # Per-host hardware and system config
├── live/                  # Config files that apply on save, no switch needed
├── modules/
│   ├── home-manager/      # User-level config (programs, dotfiles, theming)
│   ├── system/            # System-level config (boot, desktop, networking, services)
│   ├── profiles/          # Bundles hosts opt into (secureboot-laptop, vpn-workstation)
│   └── shared/            # Plain values and packages used by more than one builder
├── pkgs/                  # Local packages (flake-versions)
├── tests/                 # NixOS VM tests, run by `nix flake check`
├── secrets/               # agenix-encrypted secrets
└── templates/             # `nix flake init` templates (Rust, C/C++, Python, Typst)
```

## Secrets

Managed with [agenix](https://github.com/ryantm/agenix). Encrypted at rest,
decrypted at activation via host SSH keys.
