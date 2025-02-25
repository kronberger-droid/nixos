{
  description = "flake for kronberger";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    agenix.url = "github:ryantm/agenix";
  };

  outputs = inputs@{ self, nixpkgs, home-manager, agenix, ... }: {
    nixosConfigurations = {

      intelNuc = let
        system = "x86_64-linux";
      in nixpkgs.lib.nixosSystem {
        inherit system;
        specialArgs = {
          host = "intelNuc";
          inherit inputs;
        };
        modules = [
          ./hosts/intelNuc/configuration.nix
          ./modules/system/greetd.nix
          home-manager.nixosModules.home-manager
          ./modules/home-manager/users/kronberger.nix
          agenix.nixosModules.default
          {
            environment.systemPackages = [ agenix.packages.${system}.default ];
          }
        ];
      };

      t480s = let
        system = "x86_64-linux";
      in nixpkgs.lib.nixosSystem {
        inherit system;
        specialArgs = {
          host = "t480s";
          inherit inputs;
        };
        modules = [
          ./hosts/t480s/configuration.nix
          ./modules/system/greetd.nix
          home-manager.nixosModules.home-manager
          ./modules/home-manager/users/kronberger.nix
          agenix.nixosModules.default
          {
            environment.systemPackages = [ agenix.packages.${system}.default ];
          }
        ];
      };

      spectre = let
        system = "x86_64-linux";
      in nixpkgs.lib.nixosSystem {
        inherit system;
        specialArgs = {
          host = "spectre";
          inherit inputs;
        };
        modules = [
          ./modules/system/greetd.nix
          home-manager.nixosModules.home-manager
          ./modules/home-manager/users/kronberger.nix
          agenix.nixosModules.default
          {
            environment.systemPackages = [ agenix.packages.${system}.default ];
          }
        ];
      };

      devPi = nixpkgs.lib.nixosSysytem {
        system = "aarch64-linux";
        specialArgs = {
          host = "devPi";
        };
        modules = [
          ./hosts/devPi/configuration.nix
        ];
      };
    };
  };
}
