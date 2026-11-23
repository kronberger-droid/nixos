# Handbook

How to use what this flake builds. The `.nix` files say why each thing is the
way it is; these pages say where things are and which command gets you there.
When a page and the config disagree, the config is right and the page needs a
fix.

| Page | Answers |
|------|---------|
| [access.md](access.md) | How do I get into a machine, an account or a service? |
| [homeserver.md](homeserver.md) | What runs on the server, on which port, and how do I look after it? |
| [workflow.md](workflow.md) | How do I change, check, switch, deploy, update and roll back? |
| [network.md](network.md) | LAN, tailnet, DNS and the VPNs. |

Deeper notes that already live beside the code:

- [hosts/homeserver/matrix-whatsapp.md](../hosts/homeserver/matrix-whatsapp.md): design of the Matrix server and WhatsApp bridge, and the traps hit building it
- [hosts/edgerouter/README.md](../hosts/edgerouter/README.md): router settings that look wrong and are not
- [hosts/recovery/INSTALL.md](../hosts/recovery/INSTALL.md): installing any host from the recovery stick, with [intelNuc](../hosts/intelNuc/INSTALL.md) and [P14E](../hosts/P14E/INSTALL.md) specifics

## Quick answers

Commands are Nushell unless they run over `ssh`, where the far side is bash.

| I want to | Do this | More |
|-----------|---------|------|
| Get a shell on the homeserver | `ssh homeserver` | [access](access.md#homeserver) |
| Use Matrix or the WhatsApp bridge | Element, server `https://homeserver.tailc7340c.ts.net`, user `kronberger` | [access](access.md#matrix-and-the-whatsapp-bridge) |
| Look at the bridge when it misbehaves | `ssh homeserver journalctl -u mautrix-whatsapp -n 100` | [homeserver](homeserver.md#matrix-and-whatsapp) |
| Rebuild this machine | `flake` | [workflow](workflow.md#switching-a-workstation) |
| Rebuild this machine, building on the server | `flake -r` | [workflow](workflow.md#switching-a-workstation) |
| Deploy the homeserver | `deploy .#homeserver` in `~/.config/nixos` | [workflow](workflow.md#deploying-the-homeserver) |
| Check a change before switching | `nix flake check` | [workflow](workflow.md#checking-a-change) |
| Undo a bad switch | `flake rollback` | [workflow](workflow.md#rolling-back) |
| Add or edit a secret | `agenix -e <name>.age` in `secrets/`, on intelNuc | [workflow](workflow.md#secrets) |
| Publish the website | push the site repo, `nix flake update website`, deploy | [homeserver](homeserver.md#website) |
| Open my photos | `http://photos.home.lan:2283` on the tailnet | [homeserver](homeserver.md#services) |
| Reach the router | `https://192.168.2.1`, from the LAN or the tailnet | [access](access.md#edgerouter) |
| Start Claude Code | `claude`, which always opens in the sandbox account | [access](access.md#the-claude-sandbox) |
| Run Claude on the homeserver from my phone | `ssh homeserver claude-sandbox-open 3h`, then claude.ai | [access](access.md#the-claude-sandbox) |
| Pull the sandbox's work into my checkout | `git fetch-sandbox` | [access](access.md#the-claude-sandbox) |
| Turn a VPN on | `sudo systemctl start mullvad-wg`, `tuwien-vpn`, `sudo systemctl start pia-vpn` | [network](network.md#vpns) |
| Find out why DNS is down | `ssh homeserver systemctl status blocky dns-healthcheck` | [network](network.md#dns) |

## The machines

| Host | What | Tailnet address | Built by |
|------|------|-----------------|----------|
| `intelNuc` | Desktop. Holds the agenix editor key and the only admin ssh key. | `100.64.13.9` | `mkHost` |
| `spectre` | Convertible laptop | `100.116.232.46` | `mkHost` |
| `P14E` | Laptop | `100.103.204.24` | `mkHost` |
| `homeserver` | Always-on server, LAN `192.168.2.54` | `100.92.46.97` | `nixosSystem`, deployed with deploy-rs |
| `droid` | Phone, nix-on-droid | `100.120.115.46` | `nixOnDroidConfiguration` |
| `recovery` | Rescue ISO | none | `nix build .#recovery` |
| `edgerouter` | EdgeOS router, LAN `192.168.2.1` | none, reached through the subnet route | not built by Nix, snapshot only |

The addresses come from `modules/shared/homeserver.nix` and
`modules/shared/syncthing-devices.nix`. MagicDNS resolves the host names on
the tailnet, so the numbers are only needed when DNS is the thing that broke.
