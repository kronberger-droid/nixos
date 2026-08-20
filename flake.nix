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
    # freecad-wayland regressed on current nixos-unstable and won't build.
    # Pin it to the last nixpkgs rev we published to origin/main (d407951),
    # where it still built, while the rest of the system tracks unstable.
    # The overlay below pulls only `freecad-wayland` out of this input.
    # Drop it once unstable's freecad builds again, then bump/remove here.
    nixpkgs-freecad.url = "github:NixOS/nixpkgs/d407951447dcd00442e97087bf374aad70c04cea";
    rust-overlay = {
      url = "github:oxalica/rust-overlay";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    # Rio "nightly": upstream main built with Rio's own flake.
    #
    # Deliberately unfollowed. Rio's CI pushes builds to rioterm.cachix.org
    # (wired up in modules/system/core/nix-caches.nix), and a substituter hit
    # needs the output hash to match upstream's byte for byte. Any `follows`
    # here rewrites an input, which rewrites the hash, which turns every build
    # into a local rustc run over the whole workspace. Verified: with nixpkgs
    # and rust-overlay followed, our rio path 404s against the cache; the
    # unfollowed `.default` hits.
    #
    # Cost of unfollowing is a second nixpkgs at eval time and a parallel set
    # of runtime libs (rio pulls its own libxkbcommon etc). Rio's closure is
    # ~95M and those deps come from cache.nixos.org anyway, so the disk hit is
    # noise next to the build it saves.
    #
    # Two constraints follow from how upstream CI publishes:
    #
    #   - Use `.default`, not `.rio-stable`. CI only ever builds `.default`.
    #     Unfollowing also removes the reason we picked `.rio-stable` in the
    #     first place: that was to dodge Rio pinning its MSRV to unreleased
    #     Rust, which only bit us because we forced rust-overlay to our lock.
    #     Rio's own lock resolves its MSRV fine. `.rio-nightly` is the
    #     Rust-nightly compiler variant, likewise uncached.
    #   - Track main closely. Only the current main is in the cache; revs a
    #     few days old already 404. Bump this input often, and expect a cache
    #     miss to mean a full local build.
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
    };
    lanzaboote = {
      url = "github:nix-community/lanzaboote";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    deploy-rs = {
      url = "github:serokell/deploy-rs";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    starship-nerd-fonts = {
      url = "https://raw.githubusercontent.com/starship/starship/master/docs/public/presets/toml/nerd-font-symbols.toml";
      flake = false;
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
      # lean hosts (e.g. mediaBox) pass a trimmed one.
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
                (final: _prev: {
                  # Make pkgs.niri resolve to the same fork build — collapses
                  # the closure so scripts using `pkgs.niri/bin/niri msg` don't
                  # pull in a parallel nixpkgs niri build.
                  niri = final.niri-unstable;
                })
                # nushell from upstream main. Shared with the homeserver and
                # droid (both built outside mkHost) — see the overlay file.
                (import ./modules/shared/nushell-overlay.nix inputs)
                (_: prev: {
                  deploy-rs = inputs.deploy-rs.packages.${system}.default;
                  claude-code-bin = inputs.claude-code.packages.${system}.claude-code;
                  # Taken verbatim so it matches what upstream CI pushed to
                  # rioterm.cachix.org. See the rio-upstream input for why
                  # nothing here may be overridden or followed.
                  #
                  # This used to carry `doCheck = false`: rio's context tests
                  # fork a pty and the SIGHUP from tearing it down killed the
                  # whole `cargo test` harness inside the nix sandbox (exit
                  # 129 = 128 + SIGHUP, no assertion failure). Upstream fixed
                  # the sandbox PID 1 detection behind it in d52809a (#1855)
                  # and CI now builds with checks on, so the override is gone
                  # (it would also have cost us the cache). If a cache miss
                  # ever drops you into a local build that dies at exit 129,
                  # this is the one-liner that brings it back:
                  #
                  #   rio = inputs.rio-upstream.packages.${system}.default
                  #     .overrideAttrs (_: {doCheck = false;});
                  #
                  # Note that reinstating it forfeits the cache permanently,
                  # not just for the broken rev.
                  rio = inputs.rio-upstream.packages.${system}.default;
                  # bitwarden-desktop's checkPhase runs the desktop_native cargo
                  # tests, and a currently-failing test there breaks the build.
                  # Upstream nixpkgs already carries per-test checkFlags skips
                  # but hasn't caught this one yet. Drop the whole phase until
                  # it does; the Electron app itself is unaffected.
                  #
                  # 2026.7.0 also picks its clipboard backend off
                  # XDG_CURRENT_DESKTOP and takes the RemoteDesktop portal
                  # whenever it spots GNOME, which our niri session appends for
                  # Chromium's keyring. That portal call then always fails:
                  # desktop_core marks the process PR_SET_DUMPABLE(0) for
                  # anti-memory-dump hardening, so xdg-desktop-portal cannot
                  # read /proc/$pid/root to identify the caller and refuses it
                  # (flatpak/xdg-desktop-portal#785). Hide the GNOME token from
                  # this one app to get the working X11 backend back. Drop the
                  # wrapper at 2026.8.0, which makes X11 the default and the
                  # portal a fallback (bitwarden/clients#22062).
                  bitwarden-desktop = prev.bitwarden-desktop.overrideAttrs (old: {
                    doCheck = false;
                    nativeBuildInputs = (old.nativeBuildInputs or []) ++ [prev.makeWrapper];
                    postFixup =
                      (old.postFixup or "")
                      + ''
                        wrapProgram $out/bin/bitwarden --set XDG_CURRENT_DESKTOP niri
                      '';
                  });
                  # freecad-wayland is broken on current unstable, so pull it
                  # from nixpkgs-freecad (origin/main's last-good rev) instead.
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
      # Not yet installed; hardware-configuration.nix is a placeholder until
      # nixos-generate-config runs on the real disk.
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

      # x86 notebook media box — a "focused spectre": full niri desktop
      # (waybar, rofi, mako, nemo, keyd, theming) via the shared mkHost stack,
      # but with a lean media user (no dev toolchains, no personal apps) and a
      # lean system config (no common.nix, so no agenix/workstation services).
      mediaBox = mkHost {
        hostname = "mediaBox";
        system = x86System;
        isNotebook = true;
        # sway (prebuilt from cache) instead of the niri fork, which would add
        # a second from-source Rust build on top of the nushell overlay this
        # box now shares with every other host.
        primaryCompositor = "sway";
        username = "media";
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
          # Same upstream-main nushell as every other host. Previously
          # droid stayed on stock nixpkgs nushell to avoid an on-device Rust
          # build, but the homeserver (which builds this same overlay) is
          # already droid's remote builder/substituter, so it hands back the
          # prebuilt output instead of compiling on the phone.
          (import ./modules/shared/nushell-overlay.nix inputs)
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
      modules = [
        ./hosts/recovery/configuration.nix
        lixModule
      ];
    };
  };
}
