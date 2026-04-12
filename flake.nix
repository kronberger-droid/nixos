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
    nixpkgs-rio = {
      url = "github:kronberger-droid/nixpkgs/rio-0.3.1";
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
      inputs.nixpkgs.follows = "nixpkgs";
    };
    firefox-addons = {
      url = "gitlab:rycee/nur-expressions?dir=pkgs/firefox-addons";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    oo7-nixos = {
      url = "github:kronberger-droid/oo7-nixos";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    lix-module = {
      url = "git+https://git.lix.systems/lix-project/nixos-module?ref=release-2.93";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    notal = {
      url = "github:kronberger-droid/notal";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    deploy-rs = {
      url = "github:serokell/deploy-rs";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    nixos-hardware = {
      url = "github:NixOS/nixos-hardware";
    };
    starship-nerd-fonts = {
      url = "https://raw.githubusercontent.com/starship/starship/master/docs/public/presets/toml/nerd-font-symbols.toml";
      flake = false;
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
            {nixpkgs.overlays = [inputs.niri.overlays.niri (_: _: {rio = inputs.nixpkgs-rio.legacyPackages.${system}.rio; notal = inputs.notal.packages.${system}.default; deploy-rs = inputs.deploy-rs.packages.${system}.default;})];}
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
            inputs.oo7-nixos.nixosModules.default
            inputs.lix-module.nixosModules.default
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
          agenix.nixosModules.default
          {environment.systemPackages = [agenix.packages.${x86System}.default];}
          inputs.lix-module.nixosModules.default
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
          home-manager.nixosModules.home-manager
          ./modules/home-manager/devPi.nix
          inputs.lix-module.nixosModules.default
        ];
      };

      mediaPi = nixpkgs.lib.nixosSystem {
        specialArgs = {
          host = "mediaPi";
          inherit inputs;
        };
        modules = [
          { nixpkgs.hostPlatform = armSystem; }
          ./hosts/mediaPi/configuration.nix
          inputs.nixos-hardware.nixosModules.raspberry-pi-4
          home-manager.nixosModules.home-manager
          ./modules/home-manager/mediaPi.nix
          inputs.lix-module.nixosModules.default
        ];
      };
    };

    # Remote deployment (deploy-rs)
    deploy.nodes.homeserver = {
      hostname = "homeserver";
      sshUser = "kronberger";
      user = "root";
      profiles.system.path =
        inputs.deploy-rs.lib.${x86System}.activate.nixos
        self.nixosConfigurations.homeserver;
    };

    deploy.nodes.mediaPi = {
      hostname = "192.168.2.92";
      sshUser = "root";
      user = "root";
      profiles.system.path =
        inputs.deploy-rs.lib.${armSystem}.activate.nixos
        self.nixosConfigurations.mediaPi;
    };

    checks = nixpkgs.lib.genAttrs [x86System] (
      system:
        inputs.deploy-rs.lib.${system}.deployChecks self.deploy
    );

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

    # Build images
    # nix build .#recovery    — USB ISO
    # nix build .#mediaPi-sd  — Raspberry Pi 4 SD card
    packages.${x86System} = {
      recovery = self.nixosConfigurations.recovery.config.system.build.isoImage;
      mediaPi-sd = self.nixosConfigurations.mediaPi.config.system.build.sdImage;
    };

    nixosConfigurations.recovery = nixpkgs.lib.nixosSystem {
      system = x86System;
      modules = [
        ./hosts/recovery/configuration.nix
        inputs.lix-module.nixosModules.default
      ];
    };
  };
}
