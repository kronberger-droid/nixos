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
    claude-code = {
      url = "github:sadjow/claude-code-nix";
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
    niri-src = {
      url = "github:kronberger-droid/niri";
      flake = false;
    };
    niri = {
      url = "github:sodiboo/niri-flake";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.nixpkgs-stable.follows = "nixpkgs";
      inputs.niri-unstable.follows = "niri-src";
    };
    firefox-addons = {
      url = "gitlab:rycee/nur-expressions?dir=pkgs/firefox-addons";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    # Self-hosted NixOS module for the oo7 secret-service stack (daemon +
    # ssh-agent + PAM + portal). nixpkgs packages oo7/oo7-portal/oo7-server
    # but has no `services.oo7.*` module yet — this flake fills that gap.
    #
    # Retire when upstream lands a module. Watch for it via:
    #   - https://github.com/linux-credentials/oo7/releases
    #   - https://github.com/NixOS/nixpkgs/commits/master/pkgs/by-name/oo/oo7
    #   - https://github.com/NixOS/nixpkgs/pulls?q=oo7+in%3Atitle
    oo7-nixos = {
      url = "github:kronberger-droid/oo7-nixos";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.oo7-ssh-agent.inputs.rust-overlay.inputs.nixpkgs.follows = "nixpkgs";
    };
    lanzaboote = {
      url = "github:nix-community/lanzaboote/v1.0.0";
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
    # Inline replacement for the lix-module flake input. The module's only job
    # we care about is "make the system Nix daemon be Lix instead of CppNix",
    # which is one line against pkgs.lix from nixpkgs unstable. The upstream
    # module also applies a CppNix-compat overlay for tools like `devenv`,
    # `nixd`, `nix-du`, etc. — none of which are in this config — so we don't
    # need it. Re-add the flake input if any of those land here later.
    lixModule = {pkgs, ...}: {
      nix.package = pkgs.lix;
    };

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
            {
              nixpkgs.overlays = [
                inputs.niri.overlays.niri
                # Pin smithay git deps as FODs to avoid re-fetching on every eval.
                # Update the hash when niri-src bumps its smithay rev in Cargo.lock.
                (final: prev: {
                  niri-unstable = prev.niri-unstable.overrideAttrs (old: {
                    cargoDeps = final.rustPlatform.importCargoLock {
                      lockFile = "${inputs.niri-src}/Cargo.lock";
                      outputHashes = {
                        "smithay-0.7.0" = "sha256-NuTaQ+977mXtLmNDOkgGoG5MXmcRMPlBvn/qkCzH2aM=";
                      };
                    };
                  });
                })
                (_: _: {
                  deploy-rs = inputs.deploy-rs.packages.${system}.default;
                  claude-code-bin = inputs.claude-code.packages.${system}.claude-code;
                })
              ];
            }
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
            lixModule
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
        extraModules = [
          inputs.lanzaboote.nixosModules.lanzaboote
        ];
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
          home-manager.nixosModules.home-manager
          ./modules/home-manager/users/kronberger-server.nix
          agenix.nixosModules.default
          {environment.systemPackages = [agenix.packages.${x86System}.default];}
          lixModule
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
          lixModule
        ];
      };

      mediaPi = nixpkgs.lib.nixosSystem {
        specialArgs = {
          host = "mediaPi";
          inherit inputs;
        };
        modules = [
          {nixpkgs.hostPlatform = armSystem;}
          ./hosts/mediaPi/configuration.nix
          inputs.nixos-hardware.nixosModules.raspberry-pi-4
          home-manager.nixosModules.home-manager
          ./modules/home-manager/mediaPi.nix
          lixModule
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
      hostname = "192.168.2.94";
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
        lixModule
      ];
    };
  };
}
