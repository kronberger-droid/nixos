{
  lib,
  username,
  ...
}: {
  imports = [./nix-caches.nix];

  nix = {
    settings = {
      experimental-features = ["nix-command" "flakes"];
      # Deduplication is the nightly nix.optimise job below. The inline
      # variant hashed and hard-linked on every store add, on top of the same
      # nightly pass, for no extra space.
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
    buildMachines = [
      {
        hostName = "homeserver";
        # The builder account on the homeserver: trusted Nix user, no sudo.
        sshUser = "nix-remote";
        sshKey = "/root/.ssh/nix-builder";
        system = "x86_64-linux";
        # Matches the homeserver's own max-jobs cap (hosts/homeserver): 15 GB
        # of RAM and a dozen parallel Rust builds is a swap storm.
        maxJobs = 4;
        speedFactor = 1;
        supportedFeatures = ["nixos-test" "benchmark" "big-parallel" "kvm"];
      }
    ];
    # Use remote builders only when explicitly requested via --builders
    distributedBuilds = false;
    gc = {
      automatic = true;
      dates = "weekly";
      options = "--delete-older-than 30d";
    };
    optimise = {
      automatic = true;
      dates = ["03:45"];
    };
  };

  nixpkgs.config.allowUnfree = true;
}
