{
  description = "flake for kronberger";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    agenix.url = "github:ryantm/agenix";
    dropkitten.url = "github:kronberger-droid/dropkitten";
  };

  outputs = inputs@{ self, nixpkgs, home-manager, agenix, dropkitten, ... }: {
    nixosConfigurations = {

      intelNuc = let
        system = "x86_64-linux";
      in nixpkgs.lib.nixosSystem {
        inherit system;
        specialArgs = {
          host = "intelNuc";
          isNotebook = false;
          inherit inputs;
        };
        modules = [
          ./hosts/intelNuc/configuration.nix
          ./modules/system/greetd.nix
          home-manager.nixosModules.home-manager
          ./modules/home-manager/users/kronberger.nix
          agenix.nixosModules.default
          {
            environment.systemPackages = [
              agenix.packages.${system}.default
            ];
          }
        ];
      };

      t480s = let
        system = "x86_64-linux";
      in nixpkgs.lib.nixosSystem {
        inherit system;
        specialArgs = {
          host = "t480s";
          isNotebook = true;
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
          isNotebook = true;
          inherit inputs;
        };
        modules = [
          ./hosts/spectre/configuration.nix
          ./modules/system/greetd.nix
          home-manager.nixosModules.home-manager
          ./modules/home-manager/users/kronberger.nix
          agenix.nixosModules.default
          {
            environment.systemPackages = [ agenix.packages.${system}.default ];
          }
        ];
      };

      portable = let
        system = "x86_64-linux";
      in nixpkgs.lib.nixosSystem {
        inherit system;
        specialArgs = {
          host = "portable";
          isNotebook = false;
          inherit inputs;
        };
        modules = [
          ./hosts/portable/configuration.nix
          ./modules/system/greetd.nix
          home-manager.nixosModules.home-manager
          ./modules/home-manager/users/kronberger.nix
          agenix.nixosModules.default
          {
            environment.systemPackages = [ agenix.packages.${system}.default ];
          }
        ];
      };

      devPi = nixpkgs.lib.nixosSystem {
        system = "aarch64-linux";
        specialArgs = {
          host = "devPi";
        };
        modules = [
          home-manager.nixosModules.home-manager
          ./hosts/devPi/configuration.nix
          ./modules/home-manager/devPi.nix
        ];
      };
    };
  };
}
