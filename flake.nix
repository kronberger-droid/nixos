{
  description = "flake for kronberger";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    # freecad-wayland is not cached on current nixos-unstable (its boost and
    # ifcopenshell inputs moved and hydra has not caught up), so pulling it
    # from the tracked nixpkgs means building freecad and ifcopenshell
    # locally. Pin it to the last nixpkgs rev where it comes prebuilt, while
    # the rest of the system tracks unstable. The overlay below pulls only
    # `freecad-wayland` out of this input.
    #
    # Removal test, done against the *locked* nixpkgs store path (from
    # `nix flake archive --dry-run --json`, not any nixpkgs-looking path in
    # the store; that mistake dropped this pin once already):
    #   nix build --dry-run 'path:<that path>#freecad-wayland'
    # must report nothing to build. Then delete the input and the overlay.
    nixpkgs-freecad.url = "github:NixOS/nixpkgs/d407951447dcd00442e97087bf374aad70c04cea";
    rust-overlay = {
      url = "github:oxalica/rust-overlay";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    # Rio built from upstream main via Rio's own flake. The overlay disables
    # its checkPhase, which changes the drv hash and thus forfeits the
    # rioterm.cachix.org cache — every bump is a local build now. The old
    # byte-for-byte cache-matching setup (and its substituter in
    # nix-caches.nix) lives on in git history if checks ever come back.
    #
    # Still deliberately unfollowed: Rio's own nixpkgs/rust-overlay lock is
    # what upstream tests against, and it resolves Rio's habit of pinning its
    # MSRV to a just-released Rust — following our rust-overlay lock is how
    # that bit us before. Costs a second nixpkgs at eval time and a parallel
    # set of runtime libs, all cheap and cached.
    #
    # Use `.default`. `.rio-nightly` is not a fresher channel — it's the same
    # main source built with a Rust nightly toolchain.
    rio-upstream.url = "github:raphamorim/rio";
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
      # agenix pins its own home-manager and nix-darwin for its HM/darwin
      # modules; neither is used here, so they were two stale trees
      # (2025-04) fetched and hashed on every `nix flake update`.
      inputs.home-manager.follows = "home-manager";
      inputs.darwin.follows = "";
    };
    claude-code = {
      # Tracks latest. We briefly pinned to 2.1.168 chasing a TUI render glitch
      # (cursor escaping the input box, ghosted/overlapping redraws), but it
      # reproduced on every pinned version and in multiple terminals — it's
      # upstream issue #51828 (Ink main-screen renderer overflowing the
      # viewport), not a version regression. So no reason to forgo features.
      # The workaround is the fullscreen renderer (`/tui fullscreen`, or
      # CLAUDE_CODE_NO_FLICKER=1), used per session; claude.nix says why it
      # is not the default.
      url = "github:sadjow/claude-code-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    dropkitten = {
      url = "github:kronberger-droid/dropkitten";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    # Matt Pocock's Claude Code skills collection. Consumed as plain files
    # (flake = false): claude.nix symlinks each skill folder into
    # ~/.claude/skills/, and kronberger.nix derives the set from the repo's
    # own .claude-plugin/plugin.json. Bump with `nix flake update mattpocock-skills`.
    mattpocock-skills = {
      url = "github:mattpocock/skills";
      flake = false;
    };
    nix-pia-vpn = {
      url = "github:rcambrj/nix-pia-vpn";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    base16 = {
      url = "github:SenchoPens/base16.nix";
    };
    niri-src = {
      url = "github:kronberger-droid/niri";
      flake = false;
    };
    # epireyn's fork, not sodiboo's original. sodiboo's last human commit is
    # 2026-01-04 (c991f50d); everything since is the lockfile bot, and 74
    # issues sit open. That staleness is what broke us: sodiboo pinned
    # libdisplay-info 0.2.0 in dc61e1e6 and never followed nixpkgs to _0_3,
    # so the 2026-08-05 removal of the alias was a hard eval error. The fork
    # fixed exactly that on 2026-07-30 (2a55039d), a week before it hit us.
    # Same input names and same outputs, so this is a URL swap.
    # If this fork goes quiet too, the exit is home-manager's own
    # `wayland.windowManager.niri`, but its `settings` is an untyped KDL
    # serializer, so that's a rewrite of desktop/niri.nix, not a swap.
    niri = {
      url = "github:epireyn/niri-flake";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.nixpkgs-stable.follows = "nixpkgs";
      inputs.niri-unstable.follows = "niri-src";
      # Nothing here uses niri-stable, but the overlay defines it regardless,
      # and niri-flake resolves cargo git dependencies with
      # `allowBuiltinFetchGit`, i.e. at evaluation time. Two source trees meant
      # two Cargo.locks and thus smithay fetched twice on every eval. Pointing
      # stable at the same tree collapses that to one.
      inputs.niri-stable.follows = "niri-src";
    };
    # Self-hosted NixOS module for the parts of the oo7 secret-service stack
    # nixpkgs' own `services.oo7` (enable only: daemon, D-Bus, cap wrapper,
    # pam_oo7, portal file) still lacks: the SSH agent, the default Login
    # collection, the gcr unlock prompt, and the PAM socket-wait race fix.
    # modules/system/desktop/keyring.nix documents the split.
    #
    # Retire when nixpkgs grows an SSH agent for oo7. Watch:
    #   - https://github.com/linux-credentials/oo7/releases
    #   - https://github.com/NixOS/nixpkgs/commits/master/nixos/modules/services/desktops/oo7.nix
    oo7-nixos = {
      url = "github:kronberger-droid/oo7-nixos";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    lanzaboote = {
      url = "github:nix-community/lanzaboote";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    deploy-rs = {
      url = "github:serokell/deploy-rs";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    # nushell built from upstream main, which runs well ahead of the releases
    # nixpkgs carries — the Helix edit mode (reedline#1138 + nushell#18830) was
    # the original reason and has since shipped, but staying on main is cheap
    # and keeps us off that lag. No `ref=`, so this tracks the default branch;
    # `nix flake update nushell-src` is the bump.
    #
    # Consumed as a plain source tree even though upstream ships a flake at
    # scripts/nix: the overlay callPackages their package expression against our
    # own nixpkgs. See modules/shared/nushell-overlay.nix for why that beats
    # taking the flake.
    nushell-src = {
      url = "github:nushell/nushell";
      flake = false;
    };
    # rust-glancer: an alternative Rust LSP trading incremental analysis for a
    # sub-100MB footprint and an index that survives editor restarts. Consumed
    # as a source tree because upstream ships only VS Code `.vsix` bundles and
    # is not in nixpkgs — modules/shared/rust-glancer-overlay.nix builds the
    # server binary out of it, and helix.nix wires it in behind `helix.rustLsp`.
    #
    # Tracks the default branch, like nushell-src: the project is young enough
    # that the tagged releases lag the fixes, and nothing here is load-bearing
    # (the toggle defaults to rust-analyzer). If a bad main ever blocks a
    # rebuild, `git checkout flake.lock` on this input is the whole recovery.
    rust-glancer-src = {
      url = "github:rust-glancer/rust-glancer";
      flake = false;
    };
    # Personal site (CV / blog / publications / projects). Its flake builds the
    # Zola output into a store path; the homeserver's website.nix points nginx
    # at that path. Content lives in its own repo so writing a post is not a
    # commit against this config and a broken post cannot fail a system build
    # any later than the flake input bump.
    #
    # Publishing a change is: commit + push there, then
    #   nix flake update website && deploy .#homeserver
    website = {
      url = "github:kronberger-droid/website";
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
      # Whether the machine actually has an accelerometer, which is a much
      # narrower question than `isNotebook`: a touchscreen clamshell has no
      # reason to carry one. Gates rot8 and its waybar toggle at eval, so
      # hosts without the sensor never pull rot8 into their closure.
      hasAccelerometer ? false,
      primaryCompositor ? "niri",
      # Primary local-account username. Single source of truth: threaded into
      # both the NixOS modules (via specialArgs) and the home-manager user
      # module, which mirrors it into home.username/homeDirectory.
      username ? "kronberger",
      extraModules ? [],
      # The home-manager user module. Defaults to the full workstation user;
      # a leaner host can pass a trimmed one.
      userModule ? ./modules/home-manager/users/kronberger.nix,
    }:
      nixpkgs.lib.nixosSystem {
        inherit system;
        specialArgs = {
          host = hostname;
          inherit isNotebook hasAccelerometer inputs primaryCompositor username;
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
                (final: prev: {
                  # libinput 1.31.3 keeps a stale palm flag on a touchpad slot
                  # when the tool type changes while its fd is closed, e.g. a
                  # palm lifting while the lid switch has the touchpad
                  # suspended. Every touch in that slot is then dropped as a
                  # palm, so every gesture needs one finger more (#1319).
                  # Fixed in 1.31.901/1.32.0; the version gate drops the patch
                  # once nixpkgs gets there. Scoped to niri because a global
                  # override would rebuild qtbase and everything above it.
                  niri-unstable = prev.niri-unstable.override {
                    libinput = prev.libinput.overrideAttrs (old: {
                      patches =
                        (old.patches or [])
                        ++ final.lib.optional (final.lib.versionOlder old.version "1.31.901") (final.fetchpatch {
                          url = "https://gitlab.freedesktop.org/libinput/libinput/-/commit/d0e6d43a78ee81f077dbd0dda98827440a3b5fc2.patch";
                          hash = "sha256-fAmBVqHNoOmIUAKbGw5QBW3VGfuP4vrs3+gK++evWpw=";
                        });
                    });
                  };
                  # Make pkgs.niri resolve to the same fork build — collapses
                  # the closure so scripts using `pkgs.niri/bin/niri msg` don't
                  # pull in a parallel nixpkgs niri build.
                  niri = final.niri-unstable;
                })
                # nushell from upstream main. Shared with the homeserver and
                # droid (both built outside mkHost) — see the overlay file.
                (import ./modules/shared/nushell-overlay.nix inputs)
                # Exposes `pkgs.rust-glancer` for helix.nix. Lazy: no host
                # builds it unless `helix.rustLsp` selects it. Also applied to
                # droid, the only other config that imports the helix module.
                (import ./modules/shared/rust-glancer-overlay.nix inputs)
                (_: _: {
                  deploy-rs = inputs.deploy-rs.packages.${system}.default;
                  claude-code-bin = inputs.claude-code.packages.${system}.claude-code;
                  # rio from upstream main, tests skipped — same policy as the
                  # nushell overlay. Upstream keeps adding tests that assume a
                  # real host and each one breaks the sandboxed checkPhase for
                  # a new reason: first the pty SIGHUP (#1855, fixed), now the
                  # URL tests spawning /bin/sleep, which the sandbox doesn't
                  # have. Upstream CI already gates main, so running the suite
                  # here only ever reproduces sandbox incompatibilities.
                  #
                  # The override changes the drv hash, so rioterm.cachix.org
                  # can never hit again and every bump is a full local build
                  # (~25 min). The substituter was dropped from nix-caches.nix
                  # along with this; restore both together if checks ever go
                  # back on.
                  rio =
                    inputs.rio-upstream.packages.${system}.default.overrideAttrs
                    (_: {doCheck = false;});
                  # bitwarden-desktop is stock again. Until 2026.8.0 it carried
                  # a doCheck = false (a failing desktop_native cargo test) and
                  # a wrapper hiding the GNOME token in XDG_CURRENT_DESKTOP so
                  # it would not pick the RemoteDesktop clipboard portal, which
                  # always failed under PR_SET_DUMPABLE(0). 2026.8.0 made X11
                  # the default backend (bitwarden/clients#22062) and the
                  # locked nixpkgs builds it clean, so the cached binary is
                  # back. If the clipboard regresses, that wrapper is
                  # `wrapProgram $out/bin/bitwarden --set XDG_CURRENT_DESKTOP niri`.
                  # freecad-wayland is uncached on current unstable, so pull it
                  # from nixpkgs-freecad (the last rev where it is prebuilt).
                  # Fresh nixpkgs import needs its own allowUnfree — it does
                  # not inherit this system's nixpkgs.config. See input above.
                  freecad-wayland =
                    (import inputs.nixpkgs-freecad {
                      inherit system;
                      config.allowUnfree = true;
                    })
                    .freecad-wayland;
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

      # Laptops
      spectre = mkHost {
        hostname = "spectre";
        system = x86System;
        isNotebook = true;
        # The only convertible in the fleet, thus the only host with an
        # accelerometer to drive screen rotation.
        hasAccelerometer = true;
        extraModules = [
          inputs.lanzaboote.nixosModules.lanzaboote
        ];
      };

      # Intel NUC P14E Laptop Element — modular "Compute Element" chassis.
      # Installed; shares the secureboot-laptop profile with spectre.
      P14E = mkHost {
        hostname = "P14E";
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
          username = "kronberger";
          inherit inputs;
        };
        modules = [
          ./hosts/homeserver/configuration.nix
          # Same upstream-main nushell the mkHost hosts get. Needed because the
          # server's home-manager (useGlobalPkgs) and login shell both read
          # `edit_mode = "helix"`, which nixpkgs' release nushell still rejects.
          {
            nixpkgs.overlays = [
              (import ./modules/shared/nushell-overlay.nix inputs)
              # This host is built by nixosSystem directly rather than mkHost,
              # so it misses mkHost's overlay — claude-code-bin has to be
              # redefined here, same as the droid config does for aarch64.
              (_: _: {
                claude-code-bin = inputs.claude-code.packages.${x86System}.claude-code;
              })
            ];
          }
          home-manager.nixosModules.home-manager
          {
            home-manager.sharedModules = [
              inputs.base16.homeManagerModule
            ];
          }
          ./modules/home-manager/users/kronberger-server.nix
          agenix.nixosModules.default
          {environment.systemPackages = [agenix.packages.${x86System}.default];}
          lixModule
        ];
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
          # Same upstream-main nushell as every other host. Previously
          # droid stayed on stock nixpkgs nushell to avoid an on-device Rust
          # build, but the homeserver (which builds this same overlay) is
          # already droid's remote builder/substituter, so it hands back the
          # prebuilt output instead of compiling on the phone.
          (import ./modules/shared/nushell-overlay.nix inputs)
          # droid imports the helix module too (with helix.minimal = true), so
          # it needs the attribute to exist for `helix.rustLsp` to be flippable
          # here at all. Unreferenced while the option stays on rust-analyzer.
          (import ./modules/shared/rust-glancer-overlay.nix inputs)
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
      # MagicDNS name, so a deploy works from any tailnet peer without
      # remembering the IP. The trade-off is that a deploy which disturbs
      # tailscale on the target loses the magic-rollback confirmation
      # channel and rolls back for the wrong reason; the harmonia switch in
      # hosts/homeserver notes one such case. Switch to 100.92.46.97 if that
      # ever bites again.
      hostname = "homeserver";
      sshUser = "kronberger";
      user = "root";
      # Spelled out rather than left at deploy-rs's defaults so the rollback
      # behaviour is reviewable here: magic rollback needs the confirmation
      # to arrive within confirmTimeout after activation, and a raised
      # timeout gives sshd and the firewall time to settle after a switch
      # that changes both.
      magicRollback = true;
      autoRollback = true;
      confirmTimeout = 60;
      activationTimeout = 240;
      profiles.system.path =
        inputs.deploy-rs.lib.${x86System}.activate.nixos
        self.nixosConfigurations.homeserver;
    };

    checks = nixpkgs.lib.genAttrs [x86System] (
      system:
        inputs.deploy-rs.lib.${system}.deployChecks self.deploy
    );

    # `nix fmt -- .` — alejandra, the same formatter helix runs on save (see
    # modules/home-manager/editors/helix.nix). Declaring it here is what keeps
    # the tree consistent: on-save formatting only ever reaches files that
    # happen to be opened in helix, which is how 27 files had drifted before
    # the sweep. Both systems, so it also works from the phone.
    #
    # The `-- .` is not optional: Lix's `nix fmt` passes no path through, and
    # alejandra with no arguments reads stdin, so a bare `nix fmt` dies with
    # "unexpected end of file" instead of formatting anything.
    formatter = nixpkgs.lib.genAttrs [x86System armSystem] (
      system: nixpkgs.legacyPackages.${system}.alejandra
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
        description = "Rust project with rustPlatform packaging and a dev shell";
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
    packages.${x86System} = {
      recovery = self.nixosConfigurations.recovery.config.system.build.isoImage;
    };

    nixosConfigurations.recovery = nixpkgs.lib.nixosSystem {
      system = x86System;
      # The ISO embeds `inputs.self` (tracked files only) as /nixos-config.
      specialArgs = {inherit inputs;};
      modules = [
        ./hosts/recovery/configuration.nix
        lixModule
      ];
    };
  };
}
