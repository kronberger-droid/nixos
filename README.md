# NixOS Configuration

Personal NixOS flake configuration. This is tailored entirely to my own
machines and workflow -- it is not designed to be reusable or configurable for
others. Expect hardcoded preferences, minimal abstraction, and very few knobs
to turn.

## Hosts

| Host | Arch | Description |
|------|------|-------------|
| `intelNuc` | x86_64 | Desktop |
| `portable` | x86_64 | Desktop |
| `t480s` | x86_64 | Laptop |
| `spectre` | x86_64 | Laptop |
| `devPi` | aarch64 | ARM dev board |

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
