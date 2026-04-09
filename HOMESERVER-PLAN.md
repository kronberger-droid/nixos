# Homeserver Services Plan

## AdGuard Home (deployed)

Network-wide DNS + ad blocking, running on port 3080.

### Tailscale Admin Panel Setup

1. Go to `login.tailscale.com` → **DNS → Nameservers**
2. Add `100.92.46.97` as a custom nameserver (homeserver Tailscale IP)
3. Enable **"Override local DNS"**
4. Add fallback nameservers: `1.1.1.1`, `8.8.8.8` (used when homeserver is down)
5. Under **DNS → MagicDNS** — ensure it's enabled (auto-resolves `hostname.tailnet.ts.net`)

### Edge Router

- Set DHCP DNS primary to `192.168.2.54`, secondary to `1.1.1.1`
- Covers LAN devices not on Tailscale

### First Run

- Visit `http://homeserver:3080` to complete the setup wizard
- Set admin credentials, pick default blocklists

---

## Miniflux RSS Reader

Lightweight RSS aggregator with a clean API, backed by PostgreSQL.

### NixOS Config

```nix
services.miniflux = {
  enable = true;
  config = {
    LISTEN_ADDR = "0.0.0.0:8070";
    BASE_URL = "http://100.92.46.97:8070";
    POLLING_FREQUENCY = "15";
    CLEANUP_ARCHIVE_UNREAD_DAYS = "-1";
    CLEANUP_ARCHIVE_READ_DAYS = "60";
  };
  adminCredentialsFile = "/etc/miniflux-admin-credentials";
};

services.postgresql = {
  enable = true;
  ensureDatabases = [ "miniflux" ];
  ensureUsers = [{
    name = "miniflux";
    ensureDBOwnership = true;
  }];
};
```

### Credentials File

Create `/etc/miniflux-admin-credentials` on the server before enabling:

```
ADMIN_USERNAME=admin
ADMIN_PASSWORD=<your-password>
```

### Firewall

Open port `8070` in `allowedTCPPorts`.

### Feed Sources

- Arxiv (physics, condensed matter)
- Hacker News RSS
- YouTube channels via RSSHub
- Mastodon accounts
- Manual blog/site RSS subscriptions

### Mobile Client

Use any app supporting Miniflux API natively:
- **Android:** Capy Reader, Readrops, FeedMe
- **iOS:** Reeder 5, NetNewsWire

---

## LLM-Powered Article Reranker

A Rust service that scores unread Miniflux articles against an interest profile using Ollama, then labels recommended articles.

### Architecture

```
Miniflux API          reranker.toml (interest profile)
    |                        |
 fetch unread    ->    build prompt + article
                             |
                         Ollama API (qwen2.5:7b)
                             |
                       score 0.0-1.0
                             |
                 above threshold -> "Recommended" label
                                    via Miniflux API
```

### Config (`reranker.toml`)

```toml
[profile]
description = """
Physics masters student interested in condensed matter theory,
numerical methods, tensor networks, Rust systems programming,
NixOS, self-hosting, and distributed systems.
Prefers technical depth, papers, and tutorials over news and opinion pieces.
Dislikes: marketing, AI hype without substance, crypto.
"""

[scoring]
threshold = 0.7
model = "qwen2.5:7b"
batch_size = 20

[miniflux]
url = "http://localhost:8070"
api_key_file = "/run/secrets/miniflux-api-key"
label = "Recommended"

[ollama]
url = "http://localhost:11434"
```

### Rust Project Structure

```
reranker/
  Cargo.toml
  reranker.toml
  src/
    main.rs
    config.rs        -- loads reranker.toml
    miniflux.rs      -- fetch unread, apply labels
    ollama.rs        -- scoring API call
    scorer.rs        -- batching + threshold logic
```

### NixOS Service

```nix
services.ollama = {
  enable = true;
  acceleration = false; # CPU-only, Iris Xe experimental
};

systemd.services.reranker = {
  description = "Miniflux article reranker";
  after = [ "miniflux.service" "ollama.service" ];
  serviceConfig = {
    ExecStart = "${reranker}/bin/reranker --config /etc/reranker/reranker.toml";
    Type = "oneshot";
  };
};

systemd.timers.reranker = {
  wantedBy = [ "timers.target" ];
  timerConfig.OnCalendar = "*-*-* 03:00:00"; # daily at 3am
};
```

### Hardware Notes

- NUC13ANKi7 (i7-1360P, Iris Xe iGPU, no discrete GPU)
- `qwen2.5:7b` runs fine on CPU for a nightly batch job
- Iris Xe has experimental Ollama support via SYCL — worth testing

### What's Easy to Change Without Touching Code

| Thing           | How                                      |
|-----------------|------------------------------------------|
| Interests       | Edit `[profile] description` in toml     |
| Strictness      | Adjust `threshold`                       |
| Model           | Change `model`                           |
| Frequency       | Change `OnCalendar` in the timer         |
| Label name      | Change `label`                           |

---

## Implementation Order

1. ~~AdGuard Home~~ (done)
2. Configure Tailscale DNS + edge router DHCP
3. Miniflux + PostgreSQL
4. Add RSS feeds
5. Ollama
6. Reranker Rust project
7. Wire up as systemd timer
