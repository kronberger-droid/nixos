{lib, ...}: {
  imports = [./nix-caches.nix];

  nix = {
    settings = {
      experimental-features = ["nix-command" "flakes"];
      auto-optimise-store = true;
      max-free = 1073741824; # 1GB
      min-free = 134217728; # 128MB

      # Build optimization (hosts can override these)
      max-jobs = lib.mkDefault "auto";
      cores = lib.mkDefault 0;

      # Faster evaluation
      keep-derivations = true;
      keep-outputs = true;

      # Security
      sandbox = true;
      allowed-users = ["root" "kronberger"];
      trusted-users = ["root" "kronberger"];

      # nh handles dirty tree warnings
      warn-dirty = false;
    };
    buildMachines = [
      {
        hostName = "homeserver";
        sshUser = "kronberger";
        sshKey = "/root/.ssh/nix-builder";
        system = "x86_64-linux";
        maxJobs = 12;
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
