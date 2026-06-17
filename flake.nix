{
  description = "flake for kronberger";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    # Temporary: pull rio 0.4.3 from our open nixpkgs PR until it merges.
    # PR: https://github.com/NixOS/nixpkgs/pull/518401
    # Currently unused — overlay swapped to rio-upstream (Rio's own flake at
    # main). Kept here so a one-line overlay flip restores the 0.4.3 PR build
    # if nightly turns out unstable. Remove once we're committed to either path
    # AND 0.4.3 has landed in nixos-unstable.
    nixpkgs-rio.url = "github:kronberger-droid/nixpkgs/rio-0.4.3";
    # Rio "nightly": upstream main built with Rio's own flake.
    # We pick `.rio-stable` (latest released Rust) rather than `.default`
    # (= Rio's MSRV), because upstream pins MSRV to unreleased Rust versions
    # and rust-overlay only carries shipped stable channels. Switch back to
    # `.default` once Rio's MSRV is at or below the latest released stable.
    # `packages.${system}.rio-nightly` is the Rust-nightly compiler variant.
    # rust-overlay is hoisted from rio-upstream so we control its lock.
    # Rio's `.rio-stable` resolves to `rust-bin.stable.latest.minimal` against
    # rust-overlay's pinned rev — when rio's own flake.lock lags behind a Rust
    # release, `latest.stable` returns the old toolchain and rio's MSRV-bumped
    # source fails to compile. Locking rust-overlay here lets us refresh it
    # with `nix flake update rust-overlay` without waiting on upstream rio.
    rust-overlay = {
      url = "github:oxalica/rust-overlay";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    rio-upstream = {
      url = "github:raphamorim/rio";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.rust-overlay.follows = "rust-overlay";
    };
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    nix-on-droid = {
      url = "github:nix-community/nix-on-droid";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.home-manager.follows = "home-manager";
    };
    agenix = {
      url = "github:ryantm/agenix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    claude-code = {
      # Tracks latest. We briefly pinned to 2.1.168 chasing a TUI render glitch
      # (cursor escaping the input box, ghosted/overlapping redraws), but it
      # reproduced on every pinned version and in multiple terminals — it's
      # upstream issue #51828 (Ink main-screen renderer overflowing the
      # viewport), not a version regression. So no reason to forgo features.
      # The fix lives in claude.nix: the fullscreen renderer, enabled via the
      # CLAUDE_CODE_NO_FLICKER env var (equivalently the `/tui fullscreen` cmd).
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
      url = "github:nix-community/lanzaboote";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    deploy-rs = {
      url = "github:serokell/deploy-rs";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    nixos-hardware = {
      url = "github:NixOS/nixos-hardware";
      # Dedupe onto our nixpkgs; otherwise it pins its own stale tarball
      # nixpkgs (an unused transitive node that just bloats flake.lock).
      inputs.nixpkgs.follows = "nixpkgs";
    };
    starship-nerd-fonts = {
      url = "https://raw.githubusercontent.com/starship/starship/master/docs/public/presets/toml/nerd-font-symbols.toml";
      flake = false;
    };
    # nushell built from our fork's helix-mode-wip branch: current upstream
    # (v0.113.2) + the glue wiring reedline's selection-first Helix edit mode
    # (`edit_mode = "helix"`). Its Cargo.lock pins reedline to our fork's
    # helix-mode-wip rev, fetched as a FOD via outputHashes in the overlay
    # below (same pattern as niri-src/smithay). The reedline branch also carries
    # #1097, the leading-CRLF prompt fix our two-line prompt needs.
    nushell-helix = {
      url = "github:kronberger-droid/nushell/helix-mode-wip";
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
      # The home-manager user module. Defaults to the full workstation user;
      # lean hosts (e.g. mediaBox) pass a trimmed one.
      userModule ? ./modules/home-manager/users/kronberger.nix,
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
                # Exposes `pkgs.rust-bin` so home-manager (useGlobalPkgs) can
                # pull a toolchain from rust-overlay instead of nixpkgs' rustc,
                # which lags Rust stable. See modules/home-manager/editors/dev-tools.nix.
                inputs.rust-overlay.overlays.default
                # Pin smithay git deps as FODs to avoid re-fetching on every eval.
                # Update the hash when niri-src bumps its smithay rev in Cargo.lock.
                (final: prev: {
                  niri-unstable = prev.niri-unstable.overrideAttrs (old: {
                    cargoDeps = final.rustPlatform.importCargoLock {
                      lockFile = "${inputs.niri-src}/Cargo.lock";
                      outputHashes = {
                        "smithay-0.7.0" = "sha256-TV/GTfSvgfVwIFUGoASU7xm38opIBLjLMf1HeNTW07U=";
                      };
                    };
                  });
                  # Make pkgs.niri resolve to the same fork build — collapses
                  # the closure so scripts using `pkgs.niri/bin/niri msg` don't
                  # pull in a parallel nixpkgs niri build.
                  niri = final.niri-unstable;
                  # nushell from our helix-mode-wip fork (see the nushell-helix
                  # input). Reuses nixpkgs' build; only src + vendored deps are
                  # swapped. reedline is the lone git dep, pinned by the fork's
                  # Cargo.lock rev and fetched here as a FOD. Update the hash
                  # when the reedline rev in that Cargo.lock changes.
                  nushell = prev.nushell.overrideAttrs (old: {
                    version = "0.113.2-helix-wip";
                    src = inputs.nushell-helix;
                    cargoDeps = final.rustPlatform.importCargoLock {
                      lockFile = "${inputs.nushell-helix}/Cargo.lock";
                      outputHashes = {
                        "reedline-0.48.0" = "sha256-ICAjVrgjlOMBLafGZwvU45KXGZf3KCwfRRhgVRkkcRw=";
                      };
                    };
                    doCheck = false;
                  });
                })
                (_: _: {
                  deploy-rs = inputs.deploy-rs.packages.${system}.default;
                  claude-code-bin = inputs.claude-code.packages.${system}.claude-code;
                  rio = inputs.rio-upstream.packages.${system}.rio-stable;
                })
              ];
            }
            home-manager.nixosModules.home-manager
            {
              home-manager.sharedModules = [
                inputs.base16.homeManagerModule
              ];
            }
            userModule
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
          lixModule
        ];
      };

      # x86 notebook media box — a "focused spectre": full niri desktop
      # (waybar, rofi, mako, nemo, keyd, theming) via the shared mkHost stack,
      # but with a lean media user (no dev toolchains, no personal apps) and a
      # lean system config (no common.nix, so no agenix/workstation services).
      mediaBox = mkHost {
        hostname = "mediaBox";
        system = x86System;
        isNotebook = true;
        primaryCompositor = "niri";
        userModule = ./modules/home-manager/users/media.nix;
      };
    };

    # Nix-on-Droid (Android / Termux). Its own builder — not nixosSystem —
    # so it lives outside mkHost and nixosConfigurations.
    nixOnDroidConfigurations.droid = inputs.nix-on-droid.lib.nixOnDroidConfiguration {
      pkgs = import nixpkgs {
        system = armSystem;
        config.allowUnfree = true;
        overlays = [
          inputs.nix-on-droid.overlays.default
          inputs.rust-overlay.overlays.default
          (_: _: {
            claude-code-bin = inputs.claude-code.packages.${armSystem}.claude-code;
          })
        ];
      };
      modules = [./hosts/droid/nix-on-droid.nix];
      extraSpecialArgs = {inherit inputs;};
      home-manager-path = home-manager.outPath;
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
