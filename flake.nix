{
  description = "flake for kronberger";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    agenix = {
      url = "github:ryantm/agenix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    dropkitten = {
      url = "github:kronberger-droid/dropkitten";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    nix-pia-vpn = {
      url = "github:rcambrj/nix-pia-vpn";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    fenix = {
      url = "github:nix-community/fenix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    arrabbiata-tui = {
      url = "github:kronberger-droid/arrabbiata-tui";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    base16 = {
      url = "github:SenchoPens/base16.nix";
    };
  };

  outputs = inputs @ {
    self,
    nixpkgs,
    home-manager,
    agenix,
    ...
  }: let
    # Helper function to create host configurations
    mkHost = {
      hostname,
      system,
      isNotebook,
      extraModules ? [],
    }:
      nixpkgs.lib.nixosSystem {
        inherit system;
        specialArgs = {
          host = hostname;
          inherit isNotebook inputs;
        };
        modules =
          [
            ./hosts/${hostname}/configuration.nix
            ./modules/system/greetd.nix
            home-manager.nixosModules.home-manager
            {
              home-manager.sharedModules = [
                inputs.base16.homeManagerModule
              ];
            }
            ./modules/home-manager/users/kronberger.nix
            agenix.nixosModules.default
            {
              environment.systemPackages = [agenix.packages.${system}.default];
            }
          ]
          ++ extraModules;
      };

    # Standard system configurations
    x86System = "x86_64-linux";
    armSystem = "aarch64-linux";
  in {
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
    devShells = nixpkgs.lib.genAttrs [x86System armSystem] (system: let
      pkgs = nixpkgs.legacyPackages.${system};
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
          echo "NixOS Configuration Development Environment"
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

    # Project templates
    templates = {
      rust-simple = {
        path = ./templates/rust-simple;
        description = "Simple Rust dev shell with rustup";
      };

      rust-package = {
        path = ./templates/rust-package;
        description = "Rust project with naersk packaging and dual dev shells";
      };
    };

    defaultTemplate = self.templates.rust-simple;
  };
}
