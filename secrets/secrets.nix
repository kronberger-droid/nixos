# Each secret goes to the hosts that read it, plus `editor`, so it can
# still be edited and re-keyed from one place. Every recipient can read its
# secrets for as long as the ciphertext exists, and git keeps it forever, so
# a host that does not use a secret should not be able to open it.
let
  inherit (import ../modules/shared/host-keys.nix) intelNuc spectre homeserver P14E;
  workstations = [intelNuc spectre P14E];
  # The identity that edits and re-keys. intelNuc's host key for now: root
  # only and in a desktop that does not leave the house, unlike the laptops.
  # Meant to become a hardware key (age-plugin-yubikey), at which point this
  # line changes and `agenix -r` runs once.
  editor = intelNuc;
  # agenix evaluates this file on its own, without nixpkgs, hence no lib.
  for = hosts:
    hosts
    ++ (
      if builtins.elem editor hosts
      then []
      else [editor]
    );
in {
  "kronberger-password.age".publicKeys = for workstations;
  "pia-credentials.age".publicKeys = for workstations;
  "tuwien-vpn-password.age".publicKeys = for workstations;
  "github-token.age".publicKeys = for workstations;
  "nix-github-token.age".publicKeys = for workstations;
  # Classic PAT (repo + read:org) for the `gh` CLI, and thus gh-dash. Kept apart
  # from github-token so the Claude Code GitHub plugin and gh don't have to
  # share a scope set. Classic rather than fine-grained since gh-dash queries
  # `repository.branchProtectionRules`, which fine-grained PATs can't reach on
  # repos you don't administer (dlvhdr/gh-dash#562).
  "gh-dash-token.age".publicKeys = for workstations;
  # Fine-grained PAT for the Claude Code sandbox account
  # (modules/system/security/agent-sandbox.nix). Contents: the bare token,
  # one line. Scope it on GitHub to the repositories the agent may push to,
  # contents read/write and nothing else; it is the only GitHub credential
  # that account holds, so widening it widens the sandbox.
  "claude-github-token.age".publicKeys = for workstations;
  # The homeserver sandbox's own fine-grained PAT, apart from the one above
  # so the always-on, remotely reachable sandbox can be revoked alone. All
  # of my repositories; contents, pull requests and issues read/write; no
  # workflows, no administration. A ruleset requiring a PR on main is what
  # keeps it to branches. Contents: the bare token, one line.
  "claude-github-token-homeserver.age".publicKeys = for [homeserver];
  "tunet-credentials.age".publicKeys = for workstations;
  "tuwien-vpn-totp.age".publicKeys = for workstations;
  "spotify-password.age".publicKeys = for workstations;
  "sftp-password.age".publicKeys = for workstations;
  # rbw's device_id, one per host: the UUID Bitwarden knows the device by.
  # Not a password, but with it and the master password the new-device
  # email check is skipped, thus not in plaintext. Only the named host
  # installs its file (security/agenix.nix); it and `editor` can re-key.
  "rbw-device-id-intelNuc.age".publicKeys = for [intelNuc];
  "rbw-device-id-spectre.age".publicKeys = for [spectre];
  "rbw-device-id-P14E.age".publicKeys = for [P14E];
  # Server-only. The escrow is `editor` alone: a dead homeserver disk does
  # not take the cache signing key or the tunnel credentials with it as long
  # as intelNuc's host key survives (4811a66 escrowed these to all three
  # workstations; 17d1aec narrowed them to the readers plus editor). After
  # editing this list the .age files must be re-encrypted (`agenix -r`)
  # where a current recipient's private key lives.
  "miniflux-credentials.age".publicKeys = for [homeserver];
  "cache-private-key.age".publicKeys = for [homeserver];
  # bcrypt htpasswd line — only the server needs it.
  "radicale-htpasswd.age".publicKeys = for [homeserver];
  # plaintext CardDAV password — the user machines (vdirsyncer) need it.
  "radicale-password.age".publicKeys = for workstations;
  # Cloudflare Tunnel credentials JSON, written by `cloudflared tunnel create`.
  # Contains the tunnel secret — anyone holding it can serve traffic on the
  # tunnel's hostnames. Only the server runs cloudflared.
  "cloudflared-website.age".publicKeys = for [homeserver];
  # ZOTERO_DAV_USER / ZOTERO_DAV_PASSWORD for the WebDAV server backing Zotero
  # file sync. Only the server reads it — the Zotero clients hold the same
  # password in their own settings store, not from here.
  "webdav-zotero.age".publicKeys = for [homeserver];
  # For the nightly flake-autoupdate job (services/flake-autoupdate.nix),
  # which pushes update branches and opens PRs on its own. Both are the bare
  # token, one line. github: a fine-grained PAT on nixos, lab-servers and
  # oo7-nixos with Contents and Pull requests read/write, nothing else.
  # claude: the output of `claude setup-token`, a subscription OAuth token.
  "flake-update-github-token.age".publicKeys = for [homeserver];
  "flake-update-claude-token.age".publicKeys = for [homeserver];
}
