{config, ...}: {
  nix.settings = {
    substituters = [
      "https://cache.nixos.org/"
      "https://nix-community.cachix.org"
      "https://kronberger-droid.cachix.org"
      "https://claude-code.cachix.org"
    ];
    extra-substituters =
      if config.networking.hostName != "homeserver"
      then ["http://100.92.46.97:5001"]
      else [];
    connect-timeout = 5;
    fallback = true;
    trusted-public-keys = [
      "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY="
      "homeserver-cache:ahJGAGislENoHCxAZvgDJ7tE/k7pL2h5PvqMXoY0enY="
      "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
      "kronberger-droid.cachix.org-1:YvXP+16BzDfvTHlL8elO5D+hbQeZJxi26ewyz455sg4="
      "claude-code.cachix.org-1:YeXf2aNu7UTX8Vwrze0za1WEDS+4DuI2kVeWEE4fsRk="
    ];
  };
}
