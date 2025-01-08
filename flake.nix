{
  description = "flake for kronberger";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    home-manager.url = "github:nix-community/home-manager";
    home-manager.inputs.nixpkgs.follows = "nixpkgs";
    nixos-06cb-009a-fingerprint-sensor = {
      url = "github:ahbnr/nixos-06cb-009a-fingerprint-sensor?ref=24.11";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = inputs@{ self, nixpkgs, home-manager, nixos-06cb-009a-fingerprint-sensor, ... }: {
    nixosConfigurations = {
      intelNuc = nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";
        specialArgs = {
          host = "intelNuc";
        };
        modules = [
          ./hosts/intelNuc/configuration.nix
          ./modules/system/greetd.nix
          home-manager.nixosModules.home-manager
          ./modules/home-manager/kronberger.nix
        ];
      };

      t480s = nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";
        specialArgs = {
          host = "t480s";
        };
        modules = [
          ./hosts/t480s/configuration.nix
          ./modules/system/greetd.nix
          home-manager.nixosModules.home-manager
          ./modules/home-manager/kronberger.nix
          nixos-06cb-009a-fingerprint-sensor.nixosModules."06cb-009a-fingerprint-sensor"
        ];
      };
    };
  };
}
