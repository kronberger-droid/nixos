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
    rio = {
      url = "github:raphamorim/rio";
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
    arrabbiata = {
      url = "github:kronberger-droid/arrabbiata";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    base16 = {
      url = "github:SenchoPens/base16.nix";
    };
    niri = {
      url = "github:kronberger-droid/niri-flake";
    };
    firefox-addons = {
      url = "gitlab:rycee/nur-expressions?dir=pkgs/firefox-addons";
      inputs.nixpkgs.follows = "nixpkgs";
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
      primaryCompositor ? "niri",
      extraModules ? [],
    }:
      nixpkgs.lib.nixosSystem {
        inherit system;
        specialArgs = {
          host = hostname;
          inherit isNotebook inputs primaryCompositor;
        };
        modules =
          [
            ./hosts/${hostname}/configuration.nix
            inputs.niri.nixosModules.niri
            {nixpkgs.overlays = [inputs.niri.overlays.niri inputs.rio.overlays.default];}
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

      # Servers
      homeserver = nixpkgs.lib.nixosSystem {
        system = x86System;
        specialArgs = {
          host = "homeserver";
          inherit inputs;
          arrabbiata = inputs.arrabbiata.packages.${x86System}.default;
        };
        modules = [
          ./hosts/homeserver/configuration.nix
        ];
      };

      # ARM devices (special case without agenix and standard user config)
      devPi = nixpkgs.lib.nixosSystem {
        system = armSystem;
        specialArgs = {
          host = "devPi";
          inherit inputs;
        };
        modules = [
          ./hosts/devPi/configuration.nix
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
    # Use: nix flake init --template .#<name>
    # Or:  flake init <name>  (nushell alias)
    templates = {
      rust-simple = {
        path = ./templates/rust-simple;
        description = "Minimal Rust dev shell with rustup";
      };

      rust-cli = {
        path = ./templates/rust-cli;
        description = "Rust CLI project with rust-overlay and dev tools";
      };

      rust-gui = {
        path = ./templates/rust-gui;
        description = "Rust GUI project with Wayland/X11/OpenGL deps";
      };

      rust-package = {
        path = ./templates/rust-package;
        description = "Rust project with naersk packaging and dual dev shells";
      };

      c-cpp = {
        path = ./templates/c-cpp;
        description = "C/C++ dev shell with gcc, clangd, and analysis tools";
      };

      python = {
        path = ./templates/python;
        description = "Python dev shell with venv and Jupyter support";
      };

      typst = {
        path = ./templates/typst;
        description = "Typst document dev shell";
      };
    };

    templates.default = self.templates.rust-cli;

    # Recovery USB ISO image
    # Build with: nix build .#recovery
    packages.${x86System}.recovery = self.nixosConfigurations.recovery.config.system.build.isoImage;

    nixosConfigurations.recovery = nixpkgs.lib.nixosSystem {
      system = x86System;
      modules = [
        ./hosts/recovery/configuration.nix
      ];
    };
  };
}
