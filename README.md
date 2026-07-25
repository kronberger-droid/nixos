# NixOS Configuration

Personal NixOS flake configuration. This is tailored entirely to my own
machines and workflow -- it is not designed to be reusable or configurable for
others. Expect hardcoded preferences, minimal abstraction, and very few knobs
to turn.

## Hosts

| Host | Arch | Description |
|------|------|-------------|
| `intelNuc` | x86_64 | Desktop |
| `spectre` | x86_64 | Laptop |
| `P14E` | x86_64 | Laptop (not yet installed) |
| `homeserver` | x86_64 | Server: DNS, RSS, photos, CalDAV, binary cache, website |
| `mediaBox` | x86_64 | Media kiosk notebook |
| `devPi` | aarch64 | ARM dev board |
| `droid` | aarch64 | Phone, via nix-on-droid |
| `recovery` | x86_64 | Rescue ISO, `nix build .#recovery` |

## Structure

```
.
├── flake.nix              # Flake inputs, host definitions, dev shell, templates
├── hosts/                 # Per-host hardware and system config
├── modules/
│   ├── home-manager/      # User-level config (programs, dotfiles, theming)
│   └── system/            # System-level config (agenix, greetd, VPN, etc.)
├── secrets/               # agenix-encrypted secrets
└── templates/             # Nix flake templates (Rust)
```

## Secrets

Managed with [agenix](https://github.com/ryantm/agenix). Encrypted at rest,
decrypted at activation via host SSH keys.
