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
        "https://niri.cachix.org"
      ];
      trusted-public-keys = [
        "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY="
        "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
        "niri.cachix.org-1:Wv0OmO7PsuocRKzfDoJ3mulSl7Z6oezYhGhR+3W2964="
      ];

      # Build optimization
      max-jobs = "auto";
      cores = 0; # Use all available cores

      # Faster evaluation
      keep-derivations = true;
      keep-outputs = true;

      # Security
      sandbox = true;
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
