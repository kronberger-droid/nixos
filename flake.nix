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
    pia.url = "github:Fuwn/pia.nix";
    fenix = {
      url = "github:nix-community/fenix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    copyparty.url = "github:9001/copyparty";
  };

  outputs = inputs@{ nixpkgs, home-manager, agenix, ... }:
    let
      # Helper function to create host configurations
      mkHost = { hostname, system, isNotebook, extraModules ? [ ] }:
        nixpkgs.lib.nixosSystem {
          inherit system;
          specialArgs = {
            host = hostname;
            inherit isNotebook inputs;
          };
          modules = [
            ./hosts/${hostname}/configuration.nix
            ./modules/system/greetd.nix
            home-manager.nixosModules.home-manager
            ./modules/home-manager/users/kronberger.nix
            agenix.nixosModules.default
            {
              environment.systemPackages = [ agenix.packages.${system}.default ];
            }
          ] ++ extraModules;
        };

      # Standard system configurations
      x86System = "x86_64-linux";
      armSystem = "aarch64-linux";
    in
    {
      nixosConfigurations = {
        # Desktop systems
        intelNuc = mkHost {
          hostname = "intelNuc";
          system = x86System;
          isNotebook = false;
        };

        portable = mkHost {
          hostname = "portable";
          system = x86System;
          isNotebook = false;
        };

        # Laptops
        t480s = mkHost {
          hostname = "t480s";
          system = x86System;
          isNotebook = true;
        };

        spectre = mkHost {
          hostname = "spectre";
          system = x86System;
          isNotebook = true;
        };

        # ARM devices (special case without agenix and standard user config)
        devPi = nixpkgs.lib.nixosSystem {
          system = armSystem;
          specialArgs = {
            host = "devPi";
            inherit inputs;
          };
          modules = [
            home-manager.nixosModules.home-manager
            ./hosts/devPi/configuration.nix
            ./modules/home-manager/devPi.nix
          ];
        };
      };

      # Development shell for configuration management
      devShells = nixpkgs.lib.genAttrs [ x86System armSystem ] (system:
        let pkgs = nixpkgs.legacyPackages.${system};
        in {
          default = pkgs.mkShell {
            name = "nixos-config";
            packages = with pkgs; [
              nixpkgs-fmt
              deadnix
              statix
              nix-tree
              nix-output-monitor
              nvd
            ];
            shellHook = ''
              echo "🔧 NixOS Configuration Development Environment"
              echo "Available tools:"
              echo "  - nixpkgs-fmt: Format .nix files"
              echo "  - deadnix: Find dead/unused code"
              echo "  - statix: Linting and suggestions"
              echo "  - nix-tree: Explore dependencies"
              echo "  - nix-output-monitor: Better build output"
              echo "  - nvd: Compare derivations"
            '';
          };
        });
    };
}
