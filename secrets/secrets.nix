let
  intelNuc = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIG2nXGswPYhgVX6zwQAg3Wk8pfVw64pY+wIRIUoSyXYr root@intelNuc";
  spectre = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIMo/agXzq/uXYxPRHuxy20rD/T09I/zQzLFjFmA5b5Ic root@spectre";
  homeserver = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIGfoblAvhTOErUvBVJXFrlzUwwQeQxcsu0864ffnllpW root@homeserver";
  P14E = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIEk1t3/oxPz8Rz5UDZPyYZn0GjUkleGMfKDytYdrtzUY root@nixos";
in {
  "kronberger-password.age".publicKeys = [intelNuc spectre P14E];
  "pia-credentials.age".publicKeys = [intelNuc spectre P14E];
  "tuwien-vpn-password.age".publicKeys = [intelNuc spectre P14E];
  "github-token.age".publicKeys = [intelNuc spectre P14E];
  "nix-github-token.age".publicKeys = [intelNuc spectre P14E];
  # Classic PAT (repo + read:org) for the `gh` CLI, and thus gh-dash. Kept apart
  # from github-token so the Claude Code GitHub plugin and gh don't have to
  # share a scope set. Classic rather than fine-grained since gh-dash queries
  # `repository.branchProtectionRules`, which fine-grained PATs can't reach on
  # repos you don't administer (dlvhdr/gh-dash#562).
  "gh-dash-token.age".publicKeys = [intelNuc spectre P14E];
  "tunet-credentials.age".publicKeys = [intelNuc spectre P14E];
  "tuwien-vpn-totp.age".publicKeys = [intelNuc spectre P14E];
  "spotify-password.age".publicKeys = [intelNuc spectre P14E];
  "sftp-password.age".publicKeys = [intelNuc spectre P14E];
  "aerc-gmx-password.age".publicKeys = [intelNuc spectre P14E];
  "aerc-uptudate-password.age".publicKeys = [intelNuc spectre P14E];
  "miniflux-credentials.age".publicKeys = [homeserver];
  "cache-private-key.age".publicKeys = [homeserver];
  # bcrypt htpasswd line — only the server needs it.
  "radicale-htpasswd.age".publicKeys = [homeserver];
  # plaintext CardDAV password — the user machines (vdirsyncer) need it.
  "radicale-password.age".publicKeys = [intelNuc spectre P14E];
  # Cloudflare Tunnel credentials JSON, written by `cloudflared tunnel create`.
  # Contains the tunnel secret — anyone holding it can serve traffic on the
  # tunnel's hostnames. Only the server runs cloudflared.
  "cloudflared-website.age".publicKeys = [homeserver];
  # ZOTERO_DAV_USER / ZOTERO_DAV_PASSWORD for the WebDAV server backing Zotero
  # file sync. Only the server reads it — the Zotero clients hold the same
  # password in their own settings store, not from here.
  "webdav-zotero.age".publicKeys = [homeserver];
}
