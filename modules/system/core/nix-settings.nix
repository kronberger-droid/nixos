{
  config,
  lib,
  username,
  ...
}: let
  isHomeserver = config.networking.hostName == "homeserver";
  homeserverIp = "100.92.46.97";
in {
  imports = [./nix-caches.nix];

  # Root's ssh, i.e. the daemon's connection to the builder. Pin the host key
  # so the first offload doesn't die on an unknown host, and fail fast when
  # the homeserver is off but the tailnet is up (tailnet down already fails
  # at once: no route).
  programs.ssh = lib.mkIf (!isHomeserver) {
    knownHosts.homeserver = {
      hostNames = [homeserverIp "homeserver"];
      publicKey = (import ../../shared/host-keys.nix).homeserver;
    };
    # Last, so the Host block doesn't swallow global lines other modules
    # append (libvirt's Include would otherwise apply to this host only).
    extraConfig = lib.mkAfter ''
      Host ${homeserverIp}
        ConnectTimeout 5
    '';
  };

  nix = {
    settings = {
      # The builder fetches what cache.nixos.org has itself instead of the
      # workstation uploading it.
      builders-use-substitutes = true;

      experimental-features = ["nix-command" "flakes"];
      # Deduplication is the scheduled nix.optimise job below. The inline
      # variant hashed and hard-linked on every store add, on top of the same
      # scheduled pass, for no extra space.
      auto-optimise-store = false;
      # Mid-build GC thresholds. 128 MB / 1 GB meant the daemon only started
      # collecting once the disk was effectively full (most builds ENOSPC
      # before that) and then stopped after a token gigabyte, far short of
      # what a Rust or browser build needs to finish.
      min-free = 5368709120; # 5 GB
      max-free = 32212254720; # 30 GB

      # Build optimization (hosts can override these)
      max-jobs = lib.mkDefault "auto";
      cores = lib.mkDefault 0;

      # Faster evaluation
      keep-derivations = true;
      keep-outputs = true;

      # Security
      sandbox = true;
      allowed-users = ["root" username];
      trusted-users = ["root" username];

      # nh handles dirty tree warnings
      warn-dirty = false;

      # Silence Lix's "ill-defined escape" warnings emitted by the deploy-rs
      # input's flake.nix (e.g. "Cargo\.lock", ".*\.rs$"). Enabling the
      # deprecated feature stops the warning; it's upstream's source, not ours.
      # Lix names this `deprecated-features` (full list); the CppNix-style
      # `extra-deprecated-features` append form is unknown to Lix and itself
      # warns "unknown setting". Default is [], so listing it outright is exact.
      deprecated-features = ["broken-string-escape"];
    };

    # Authenticate GitHub API requests when resolving `github:` flake inputs,
    # lifting the anonymous 60 req/hr rate limit to 5000/hr (avoids the HTTP 403
    # "rate limit exceeded" on `nix flake update`). The token lives in an agenix
    # secret; `!include` keeps it out of the world-readable /etc/nix/nix.conf,
    # and the leading `!` makes nix skip the file silently on hosts/boots where
    # it hasn't been decrypted yet instead of erroring.
    extraOptions = ''
      !include /run/secrets/nix-github-token
    '';
    # Every workstation build offloads to the homeserver without a flag:
    # `nh os switch`, `nix build`, a dev shell's inputs. Results come back
    # over ssh and the homeserver keeps a copy, so harmonia serves them to
    # the next workstation. When it is unreachable the daemon falls back to
    # a local build; ConnectTimeout below keeps that to seconds rather than
    # the minute ssh waits by default (measured 2m21s for one derivation,
    # two attempts). With the local job slots still open, a build that finds
    # the builder's four slots busy runs locally too.
    buildMachines = lib.mkIf (!isHomeserver) [
      {
        # The tailnet address, like the substituter in nix-caches.nix: root's
        # ssh has no `homeserver` alias, and the IP keeps MagicDNS out of it.
        hostName = homeserverIp;
        # The daemon protocol `flake --remote` already uses, not legacy ssh://.
        protocol = "ssh-ng";
        # The builder account on the homeserver: trusted Nix user, no sudo.
        sshUser = "nix-remote";
        # The daemon runs as root and authenticates as the host itself. The
        # homeserver authorizes these keys from shared/host-keys.nix, so
        # there is no per-host key to generate or secret to ship.
        sshKey = "/etc/ssh/ssh_host_ed25519_key";
        system = "x86_64-linux";
        # Matches the homeserver's own max-jobs cap (hosts/homeserver): 15 GB
        # of RAM and a dozen parallel Rust builds is a swap storm.
        maxJobs = 4;
        speedFactor = 1;
        supportedFeatures = ["nixos-test" "benchmark" "big-parallel" "kvm"];
      }
    ];
    distributedBuilds = !isHomeserver;
    # The dates are the always-on schedule the homeserver runs. Workstations
    # replace them in maintenance-schedule.nix.
    gc = {
      automatic = true;
      dates = lib.mkDefault "weekly";
      options = "--delete-older-than 30d";
    };
    optimise = {
      automatic = true;
      dates = lib.mkDefault ["03:45"];
    };
  };

  nixpkgs.config.allowUnfree = true;
}
