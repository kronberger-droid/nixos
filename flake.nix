{
  description = "flake for kronberger";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    # zotero copies nixpkgs' firefox-esr-153 and its build script patches
    # ActorManagerParent.sys.mjs, which no longer matches on 153.4
    # (NixOS/nixpkgs#568692). Pin to the last rev on 153.3, where zotero is
    # cached. #572466 is in unstable, but it "fixes" this by building against
    # a revived Firefox 140 ESR that is EOL (2026-10-13, knownVulnerabilities),
    # unfree and never cached, so taking it would mean permittedInsecurePackages
    # and a local Firefox build to trade a weeks-old 153.3 for an unpatched
    # 140. Keep the pin until unstable's zotero builds on a supported ESR
    # again; then drop this input and the overlay entry.
    nixpkgs-zotero.url = "github:NixOS/nixpkgs/7a0f122f5090cf4c2ade2a13a0e229d4e19ba71f";
    # nixpkgs 3ec6363 moved the python `mcp` SDK to 2.x, which fastmcp 3.4.7
    # does not support yet, so fastmcp-slim is marked broken there
    # (`broken = versionAtLeast mcp.version "2"`) and with it zotero-mcp.
    # Pin zotero-mcp's python set to the last rev on mcp 1.x. Drop this input
    # and the overlay entry once unstable's fastmcp evaluates again.
    nixpkgs-mcp.url = "github:NixOS/nixpkgs/02c087f3fe673c9e317f206a627cb6b910336dbe";
    # ladybird 2026-10-14 fails on rustc 1.99, which deprecated the
    # `fetch_update` its AK crate calls, under its own -Dwarnings. Pin to the
    # rev before, where the 2026-10-06 build is cached. NixOS/nixpkgs#576716
    # fixes it; drop this input and the overlay entry once the locked
    # nixos-unstable contains that merge.
    nixpkgs-ladybird.url = "github:NixOS/nixpkgs/7fd4004d0511991fff3a0524856a9be09e28c5f0";
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
    # Helix from master; the last release (25.07.1) trails it by over a year.
    # Unfollowed on purpose: helix.cachix.org (nix-caches.nix) holds builds
    # against helix's own nixpkgs lock, and following ours would change the
    # drv hash and miss it. The cache carries x86_64 only, so the overlay
    # applies to the workstations; droid keeps nixpkgs' helix rather than
    # compiling it on the phone.
    helix.url = "github:helix-editor/helix";
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
    # sieb: the dmenu-first picker behind the launcher, power menu, rbw
    # picker and screenrec prompts, which replaced rofi everywhere. See
    # modules/home-manager/desktop/sieb.nix.
    sieb = {
      url = "github:kronberger-droid/sieb/main";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.rust-overlay.follows = "rust-overlay";
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
    # Declarative bubblewrap sandboxes for GUI apps (home-manager/apps/signal.nix).
    nixpak = {
      url = "github:nixpak/nixpak";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    # Declarative Flathub apps (home-manager/apps/flatpak.nix). `latest`
    # tracks the newest release tag rather than main.
    nix-flatpak.url = "github:gmodena/nix-flatpak/?ref=latest";
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
      inputs.rust-overlay.follows = "rust-overlay";
    };
    # Declarative partitioning. Hosts that import modules/system/boot/disk-layout.nix
    # get their disk described in the flake, so an install is `disko` plus
    # `nixos-install` with no UUIDs to copy back afterwards.
    disko = {
      url = "github:nix-community/disko";
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

    # Overlays every host with a user on it takes, droid included, so mkHost,
    # the homeserver and droid cannot drift apart on them. The recovery ISO
    # needs none of them. commonOverlays below adds upstream-main nushell on
    # top; droid takes only these.
    baseOverlays = system: [
      # Exposes `pkgs.rust-bin` so home-manager (useGlobalPkgs) can pull a
      # toolchain from rust-overlay instead of nixpkgs' rustc, which lags Rust
      # stable. See modules/home-manager/editors/dev-tools.nix, which the
      # homeserver's Claude Code sandbox account imports too. Additive, so
      # nothing else is rebuilt.
      inputs.rust-overlay.overlays.default
      (final: _: {
        claude-code-bin = inputs.claude-code.packages.${system}.claude-code;
        # What an update would change beyond the closure diff; used by hand
        # and by the homeserver's flake-autoupdate job. See its default.nix.
        flake-versions = final.callPackage ./pkgs/flake-versions {};
      })
    ];

    # nushell from upstream main; see the overlay file. Droid stays on
    # nixpkgs' release nushell instead: its aarch64 build of main is not in
    # any cache, so every bump compiled under qemu on the homeserver for
    # hours, while the release build comes straight from cache.nixos.org.
    # The release (0.116.1 at the time of writing) accepts `edit_mode =
    # "helix"`, the setting the overlay was first brought in for.
    commonOverlays = system:
      baseOverlays system
      ++ [(import ./modules/shared/nushell-overlay.nix inputs)];

    # The NixOS modules every nixosSystem host with a user on it shares:
    # home-manager with the base16 scheme module, agenix, and Lix. Droid has
    # its own builder and takes none of these from here.
    commonModules = system: [
      home-manager.nixosModules.home-manager
      {
        home-manager.sharedModules = [
          inputs.base16.homeManagerModule
          # Inert unless the host enables services.flatpak.
          inputs.nix-flatpak.homeManagerModules.nix-flatpak
        ];
      }
      agenix.nixosModules.default
      ({config, ...}: {
        # The CLI with the system's Lix instead of the CppNix it bundles,
        # which warns "unknown setting 'deprecated-features'" on every run:
        # that key is Lix's spelling (core/nix-settings.nix).
        environment.systemPackages = [
          (agenix.packages.${system}.default.override {nix = config.nix.package;})
        ];
      })
      lixModule
    ];

    # Helper function to create host configurations
    mkHost = {
      hostname,
      system,
      isNotebook,
      # Whether the machine actually has an accelerometer, which is a much
      # narrower question than `isNotebook`: a touchscreen clamshell has no
      # reason to carry one. Gates rot8 at eval, so hosts without the
      # sensor never pull it into their closure.
      hasAccelerometer ? false,
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
          inherit isNotebook hasAccelerometer inputs username;
        };
        modules =
          [
            ./hosts/${hostname}/configuration.nix
            inputs.niri.nixosModules.niri
            {
              nixpkgs.overlays =
                [
                  inputs.niri.overlays.niri
                ]
                ++ commonOverlays system
                ++ [
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
                  (_: _: {
                    deploy-rs = inputs.deploy-rs.packages.${system}.default;
                    # Unmodified, so helix.cachix.org hits; see the helix input.
                    helix = inputs.helix.packages.${system}.default;
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
                    # zotero fails on unstable's firefox-esr 153.4. See the
                    # nixpkgs-zotero input above.
                    zotero = (import inputs.nixpkgs-zotero {inherit system;}).zotero;
                    # See the nixpkgs-ladybird input above.
                    ladybird = (import inputs.nixpkgs-ladybird {inherit system;}).ladybird;
                  })
                  # Ladybird's desktop and D-Bus files launch it with
                  # --force-new-process, which upstream turned into an alias for
                  # --temporary-profile. Every launcher start got a throwaway
                  # profile in /tmp, so settings and logins never stuck.
                  # Rewritten in a symlinkJoin so the cached build is reused.
                  # --replace-fail breaks this once upstream drops the flag
                  # (LadybirdBrowser/ladybird#12576); delete it then.
                  (_: prev: {
                    ladybird = prev.symlinkJoin {
                      name = "ladybird-${prev.ladybird.version}";
                      inherit (prev.ladybird) version meta;
                      paths = [prev.ladybird];
                      postBuild = ''
                        for f in share/applications/org.ladybird.Ladybird.desktop share/dbus-1/services/org.ladybird.Ladybird.service; do
                          rm "$out/$f"
                          substitute "${prev.ladybird}/$f" "$out/$f" --replace-fail " --force-new-process" ""
                        done
                      '';
                    };
                  })
                ];
            }
            userModule
            inputs.oo7-nixos.nixosModules.default
          ]
          ++ commonModules system
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
      };

      # Intel NUC P14E Laptop Element — modular "Compute Element" chassis.
      # Installed; shares the secureboot-laptop profile with spectre.
      P14E = mkHost {
        hostname = "P14E";
        system = x86System;
        isNotebook = true;
      };

      # Servers
      homeserver = nixpkgs.lib.nixosSystem {
        system = x86System;
        specialArgs = {
          host = "homeserver";
          username = "kronberger";
          inherit inputs;
        };
        # Built by nixosSystem directly rather than mkHost: no niri, no
        # desktop overlays, and a lean user module of its own.
        modules =
          [
            ./hosts/homeserver/configuration.nix
            {nixpkgs.overlays = commonOverlays x86System;}
            ./modules/home-manager/users/kronberger-server.nix
          ]
          ++ commonModules x86System;
      };
    };

    # Nix-on-Droid (Android / Termux). Its own builder — not nixosSystem —
    # so it lives outside mkHost and nixosConfigurations.
    nixOnDroidConfigurations.droid = inputs.nix-on-droid.lib.nixOnDroidConfiguration {
      pkgs = import nixpkgs {
        system = armSystem;
        config.allowUnfree = true;
        overlays =
          [inputs.nix-on-droid.overlays.default]
          ++ baseOverlays armSystem;
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

    # `nix flake check` is the whole pre-switch gate, so nobody has to
    # hand-roll a loop over the hosts again.
    checks = nixpkgs.lib.genAttrs [x86System] (
      system: let
        pkgs = nixpkgs.legacyPackages.${system};
        lib = nixpkgs.lib;
        hosts =
          lib.filterAttrs
          (_: c: c.pkgs.stdenv.hostPlatform.system == system)
          self.nixosConfigurations;
      in
        inputs.deploy-rs.lib.${system}.deployChecks self.deploy
        # One per host: evaluates the whole system without building it. The
        # drv path is written out with its context dropped, so forcing it
        # instantiates the toplevel but never realises it.
        // lib.mapAttrs' (name: c:
          lib.nameValuePair "eval-${name}" (pkgs.writeText "eval-${name}"
            (builtins.unsafeDiscardStringContext c.config.system.build.toplevel.drvPath)))
        hosts
        // {
          # The flake-autoupdate uid split, in a VM: the agent account must
          # not reach the job's GitHub token or state.
          flake-autoupdate = import ./tests/flake-autoupdate.nix {
            inherit pkgs inputs;
            overlays = commonOverlays system;
          };
          format = pkgs.runCommand "alejandra-check" {} ''
            ${pkgs.alejandra}/bin/alejandra --check --quiet ${self} && touch $out
          '';
          # The .nu files are templates: `@nu@`, `@bridge@` and friends are
          # substituted at build time, so each placeholder becomes a dummy
          # path before parsing. nu-check is false on a parse error.
          #
          # The nushell is a host's, i.e. the overlay's build of upstream
          # main: parsing with nixpkgs' release would check against a
          # language one version behind the shell that runs these. `source`
          # resolves at parse time, so every `source ~/...` target gets an
          # empty stub; each sourced file is checked on its own anyway. `use`
          # does too, and the bar's scripts `use "@barLib@"`, so that one
          # placeholder points at a substituted copy of the real lib.nu
          # instead, which also checks that what they import exists.
          nu-parse =
            pkgs.runCommand "nu-parse-check" {
              nativeBuildInputs = [(lib.head (lib.attrValues hosts)).pkgs.nushell];
            } ''
              export HOME=$TMPDIR
              for p in $(grep -rhoE '^\s*source ~/[^ ]+' ${self} --include='*.nu' | sed 's/.*source ~\///'); do
                mkdir -p "$HOME/$(dirname "$p")" && touch "$HOME/$p"
              done
              sed 's/@[A-Za-z_]*@/\/placeholder/g' \
                ${self}/modules/home-manager/desktop/ironbar/nu/lib.nu > "$TMPDIR/bar-lib.nu"
              fail=0
              for f in $(cd ${self} && find . -name '*.nu'); do
                sed -e "s|@barLib@|$TMPDIR/bar-lib.nu|g" -e 's/@[A-Za-z_]*@/\/placeholder/g' \
                  "${self}/$f" > "$TMPDIR/check.nu"
                if ! nu --no-config-file -c "if not (nu-check '$TMPDIR/check.nu') { exit 1 }"; then
                  echo "nu-check: $f does not parse" >&2
                  fail=1
                fi
              done
              [ $fail -eq 0 ] && touch $out
            '';
        }
    );

    # The environment of every unattended agent: modules/shared/agent-tools.nix
    # on PATH and nothing else. `nix develop .#agent --ignore-environment`
    # reproduces what the flake-autoupdate agent runs with, for trying a
    # prompt by hand.
    devShells = nixpkgs.lib.genAttrs [x86System] (system: let
      pkgs = import nixpkgs {
        inherit system;
        overlays = commonOverlays system;
        config.allowUnfree = true;
      };
    in {
      agent = pkgs.mkShellNoCC {
        packages = import ./modules/shared/agent-tools.nix pkgs;
      };
    });

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
