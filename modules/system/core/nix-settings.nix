_: {
  nix = {
    settings = {
      experimental-features = ["nix-command" "flakes"];
      auto-optimise-store = true;
      max-free = 1073741824; # 1GB
      min-free = 134217728; # 128MB
      substituters = [
        "https://cache.nixos.org/"
        "https://nix-community.cachix.org"
        "https://kronberger-niri.cachix.org"
      ];
      trusted-public-keys = [
        "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY="
        "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
        "kronberger-niri.cachix.org-1:GwmMCxswXvFn9PwMw32DFPaREyBBdkw1RLpW+7pfarI="
      ];

      # Build optimization
      max-jobs = "auto";
      cores = 0; # Use all available cores

      # Faster evaluation
      keep-derivations = true;
      keep-outputs = true;

      # Security
      sandbox = true;
      allowed-users = ["root" "kronberger"];

      # nh handles dirty tree warnings
      warn-dirty = false;
    };
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
