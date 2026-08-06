# Nushell prompt config (portable)

A plain-nushell extraction of the prompt setup that lives in
`modules/home-manager/shell/nushell.nix` and
`modules/home-manager/shell/nushell/extra_config.nu` — no Nix, no
home-manager, so it can be shared with people not on NixOS.

Two lines:

```
 ~/Projects/rust/foo  main [!] via  1.90.0 at 14:32
: |
```

Line one is Starship (all modules, one row). Line two is the vi/helix mode
indicator plus your input. The newline between them is appended in nushell, not
by Starship — see the comments in `config.nu` and `starship.toml` for why that
matters.

## Files

| File | Goes to |
| --- | --- |
| `starship.toml` | `~/.config/starship.toml` |
| `env.nu` | merge into `~/.config/nushell/env.nu` |
| `config.nu` | merge into `~/.config/nushell/config.nu` |

## Requirements

- nushell (tested on 0.114)
- starship
- a Nerd Font — `starship.toml` is built on the upstream `nerd-font-symbols`
  preset, so without one the module symbols render as boxes

## Install

```nu
cp starship.toml ~/.config/starship.toml

# then append the two snippets to your existing nushell config
open env.nu    | save --append ~/.config/nushell/env.nu
open config.nu | save --append ~/.config/nushell/config.nu
```

Restart nushell. `env.nu` regenerates `vendor/autoload/starship.nu` on every
startup, so the integration always matches the installed starship version.

## Ordering caveat

The `PROMPT_COMMAND` wrapper in `config.nu` reads the existing
`$env.PROMPT_COMMAND` and wraps it, so it must run *after* Starship's init has
installed its own closure. Autoload files run before `config.nu`, so appending
the snippet at the end of `config.nu` is correct. If you load Starship some
other way (e.g. `source` inside `config.nu`), keep the wrapper below that line.

## Not included

Deliberately scoped to the prompt. The upstream config also sets
`shell_integration` (OSC 133/633), a helix edit mode from a nushell fork,
keybindings, and a pile of custom commands — none of which affect how the
prompt renders.

`config.nu` here sets `edit_mode = 'vi'`; the original uses `'helix'`, which
only exists in a patched nushell (reedline's Helix mode). With `edit_mode` set
to `'emacs'` the `PROMPT_INDICATOR_VI_*` variables are unused — set
`$env.PROMPT_INDICATOR` instead.
