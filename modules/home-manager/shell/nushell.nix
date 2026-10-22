{
  pkgs,
  config,
  lib,
  options,
  inputs,
  ...
}: let
  hasTerminal = options ? terminal;

  # The vault lives in `vault.path` (apps/obsidian.nix), declared only for
  # users that import the apps tree; the server and droid users fall back to
  # the same default. Written with `~` because the nu helpers `path expand`
  # it and starship matches its substitutions against the contracted path.
  vaultPath =
    if options ? vault
    then config.vault.path
    else "${config.home.homeDirectory}/Documents/notes/general-vault";
  vaultTilde = lib.replaceStrings [config.home.homeDirectory] ["~"] vaultPath;

  # Centralised personal directory paths — change here, updates everywhere
  dirs = {
    nixosConfig = "~/.config/nixos";
    templates = "~/.config/nixos/templates";
    projects = "~/Projects";
    vault = vaultTilde;
  };
in {
  home.packages = with pkgs; [
    gitui
  ];

  # The helix_* keybinding modes need a nushell that knows them; every host
  # gets the upstream-main build via the shared overlay, so this goes in as-is.
  xdg.configFile."nushell/keybindings.nu".source = ./nushell/keybindings.nu;
  xdg.configFile."nushell/cl.nu".source = ./nushell/cl.nu;
  xdg.configFile."nushell/fetch.nu".source = ./nushell/fetch.nu;

  # Generated so it can use centralised path variables
  xdg.configFile."nushell/utilities.nu".text = ''
    # Utility functions for various tasks

    # Quick Q&A using Claude Haiku — pipe a question or pass directly
    def ask [question?: string] {
        let q = if ($question | is-not-empty) { $question } else { $in }
        $q | claude -p --model haiku --system-prompt "Answer in 1-3 concise sentences. Be direct, no preamble."
    }

    # Open helix in the Obsidian vault. `cd` is scoped to this function, so
    # your shell's working dir is unchanged after you quit helix.
    def vault [] {
        let dir = ("${dirs.vault}" | path expand)
        if not ($dir | path exists) {
            print $"(ansi red)Vault not found: ($dir)(ansi reset)"
            return
        }
        cd $dir
        hx .
    }

    # Launch a GUI app detached from this shell — survives closing the terminal
    def detach [...cmd: string] {
        ^setsid -f ...$cmd out> /dev/null err> /dev/null
    }

    # Pick a color from the screen with niri's built-in picker and copy the
    # hex to the clipboard. Escape cancels; niri then prints null.
    def color-picker [] {
        let picked = (niri msg -j pick-color | from json)
        if $picked == null { return }
        let rgb = ($picked.rgb | each {|c| $c * 255 | math round | into int })
        let hex = ($rgb
            | each {|c| $c | fmt | get lowerhex | str substring 2.. | fill --alignment right --width 2 --character '0' }
            | str join
            | $"#($in)")
        $hex | wl-copy
        [[type value]; [RGB ($rgb | str join ', ')] [HEX $hex]]
    }

    # Watch every .typ file in a folder, optionally writing PDFs to a separate output dir.
    # Each `typst watch` runs in the background; Ctrl+C stops them all.
    def typst-watch-all [
        folder: path                       # folder containing .typ files
        --output (-o): path                # optional output folder for the .pdf files
    ] {
        let src = ($folder | path expand)
        if not ($src | path exists) {
            print $"Error: folder not found: ($src)"
            return
        }

        let out = if ($output | is-empty) { $src } else { $output | path expand }
        if not ($out | path exists) {
            mkdir $out
        }

        let files = (glob ($src | path join "*.typ"))
        if ($files | is-empty) {
            print $"No .typ files in ($src)"
            return
        }

        let pids = ($files | each { |f|
            let f_str = ($f | into string)
            let stem = ($f_str | path basename | str replace --regex '\.typ$' "")
            let pdf = ($out | path join $"($stem).pdf")
            print $"watching ($f_str) -> ($pdf)"
            job spawn { ^typst watch $f_str $pdf out> /dev/null err> /dev/null }
        })

        print "Press Ctrl+C to stop all watchers."
        try {
            loop { sleep 1sec }
        } catch {
            $pids | each { |id| try { job kill $id } }
            print "stopped."
        }
    }

    # Mount/unmount the IAP fileserver (VPN-gated) over sshfs.
    # Connect the VPN *first*. reconnect + keepalive turn a VPN drop into a
    # bounded I/O error and auto-recovery instead of an indefinite hang. The
    # mountpoint lives under ~/Network so syncthing never scans it.
    #   iap-server            mount (default)
    #   iap-server unmount    unmount before dropping the VPN
    #   iap-server unmount -f lazy-detach a wedged mount (connection died)
    #   iap-server status     show whether it's mounted
    #   iap-server connect    interactive ssh, e.g. to accept the host key once
    def iap-server [
        action: string = "mount"   # mount, unmount, status, connect
        --force (-f)               # for unmount: lazy-detach a wedged mount
    ] {
        let host = "kronberger@iap-fileserver-1.iap.tuwien.ac.at"
        let remote = "/sph"
        let port = 10222
        let mountpoint = ("~/Network/iap-server" | path expand)
        let listed = (^mount | lines | where ($it | str contains $mountpoint) | is-not-empty)
        # A listed mount whose sshfs died (or whose link hangs) is stale, not mounted
        let mounted = $listed and ((^timeout 2 ls $mountpoint | complete).exit_code == 0)
        let stale = $listed and not $mounted

        match $action {
            "mount" => {
                if $mounted {
                    print $"(ansi yellow)Already mounted at ($mountpoint)(ansi reset)"
                    return
                }
                if $stale {
                    fusermount3 -uz $mountpoint
                    print $"(ansi yellow)Detached stale mount at ($mountpoint)(ansi reset)"
                }
                mkdir $mountpoint
                $"(open /run/secrets/sftp-password | str trim)(char newline)"
                | sshfs $"($host):($remote)" $mountpoint -o $"password_stdin,reconnect,ServerAliveInterval=15,ServerAliveCountMax=3,port=($port)"
                print $"(ansi green)Mounted ($host):($remote) -> ($mountpoint)(ansi reset)"
            }
            "unmount" => {
                if $force or $stale {
                    fusermount3 -uz $mountpoint   # lazy: detach even while "busy"
                    print $"(ansi green)Force-unmounted ($mountpoint)(ansi reset)"
                } else if not $mounted {
                    print $"(ansi yellow)Not mounted: ($mountpoint)(ansi reset)"
                } else {
                    fusermount3 -u $mountpoint
                    print $"(ansi green)Unmounted ($mountpoint)(ansi reset)"
                }
            }
            "status" => {
                if $mounted {
                    print $"(ansi green)mounted(ansi reset) at ($mountpoint)"
                } else if $stale {
                    print $"(ansi red)stale(ansi reset) at ($mountpoint) \(run `iap-server` to remount)"
                } else {
                    print $"(ansi yellow)not mounted(ansi reset)"
                }
            }
            "connect" => {
                ^ssh -p $port $host
            }
            _ => {
                print $"(ansi red)Unknown action '($action)'(ansi reset)"
                print "Usage: iap-server [mount | unmount | status | connect]  (unmount -f to force)"
            }
        }
    }
  '';

  # Generate development.nu with dynamic terminal configuration (requires terminal module)
  xdg.configFile."nushell/development.nu" = lib.mkIf hasTerminal {
    text = ''
      # Development environment setup and utilities

      # Detect dev shell and direnv
      def detectDevEnv [] {
          let has_direnv = ('.envrc' | path exists)
          let has_flake = ('flake.nix' | path exists)
          let dev_shell = if $has_flake and not $has_direnv {
              try {
                  ^nix eval --json .#devShells.x86_64-linux.dev err> /dev/null
                  ".#dev"
              } catch {
                  ".#default"
              }
          } else {
              ""
          }
          { has_direnv: $has_direnv, has_flake: $has_flake, dev_shell: $dev_shell }
      }

      # Open the terminal in a directory and run a command there. Honours
      # terminal.cwdViaExec the same way desktop/niri.nix's termSpawn does:
      # rio's --working-dir is broken, so on rio the cd happens inside a
      # bash -c wrapper instead of via the flag.
      ${
        if config.terminal.cwdViaExec
        then ''
          def termIn [cwd: string, cmd: string] {
              $"${config.terminal.bin} ${config.terminal.execFlag} ${pkgs.bash}/bin/bash -c \"cd '($cwd)' && exec ($cmd)\""
          }
        ''
        else ''
          def termIn [cwd: string, cmd: string] {
              $"${config.terminal.bin} ${config.terminal.workingDirFlag}=($cwd) ${config.terminal.execFlag} ($cmd)"
          }
        ''
      }

      # Build a terminal command string with optional dev shell wrapping
      def termCmd [cwd: string, dev_env: record, exec_args: string] {
          if $dev_env.has_direnv or not $dev_env.has_flake {
              termIn $cwd $exec_args
          } else {
              termIn $cwd $"nix develop ($dev_env.dev_shell) -c ($exec_args)"
          }
      }

      # Build a claude terminal command string. With a sandbox checkout of
      # this repo (cl.nu), the pane runs `cl`, which crosses over and picks
      # between several matches itself; no local dev shell around it, since
      # the sandbox builds its own. Otherwise claude runs here.
      def claudeCmd [cwd: string, dev_env: record] {
          if (cl-matches | is-not-empty) {
              termIn $cwd "nu -l -c cl"
          } else if $dev_env.has_direnv or not $dev_env.has_flake {
              termIn $cwd "sh -c 'exec claude'"
          } else {
              termIn $cwd $"nix develop ($dev_env.dev_shell) -c sh -c 'exec claude'"
          }
      }

      # Niri development layout setup
      # Layout: left tabbed column = helix + shell, right column = claude
      # Typst: left tabbed column = zathura + typst watch, right tabbed column = helix + claude
      def niriDevSetup [] {
          let cwd = $env.PWD
          let dev_env = detectDevEnv
          let is_typst = (glob *.typ | length) > 0

          if $is_typst {
              print "Setting up Niri typst layout..."
          } else {
              print "Setting up Niri development layout..."
          }

          # Enable tabbed display on the original terminal's column
          ^niri msg action toggle-column-tabbed-display

          if $is_typst {
              # typst watch goes up first so main.pdf exists when zathura opens
              ^niri msg action spawn -- sh -c (termCmd $cwd $dev_env $"typst watch ($cwd)/main.typ ($cwd)/main.pdf")
              sleep 500ms

              ^niri msg action spawn -- zathura ($cwd + "/main.pdf")
              sleep 500ms

              # Pair zathura with typst watch, zathura on top, then tab the column
              ^niri msg action consume-or-expel-window-left
              ^niri msg action move-window-up
              ^niri msg action toggle-column-tabbed-display

              # Park that column left of the original terminal and focus back to it
              ^niri msg action move-column-left
              ^niri msg action focus-column-right

              # Claude joins the original terminal's tabbed column, helix stays visible
              ^niri msg action spawn -- sh -c (claudeCmd $cwd $dev_env)
              sleep 500ms
              ^niri msg action consume-or-expel-window-left
              ^niri msg action focus-window-up
          } else {
              # Spawn shell terminal (receives focus)
              ^niri msg action spawn -- sh -c (termCmd $cwd $dev_env "nu --login")
              sleep 500ms

              # Move shell into the tabbed column
              ^niri msg action consume-or-expel-window-left

              # Spawn Claude terminal as the right column
              ^niri msg action spawn -- sh -c (claudeCmd $cwd $dev_env)
              sleep 500ms

              # Focus back to left column, top window (original terminal for helix)
              ^niri msg action focus-column-left
              ^niri msg action focus-window-up
          }

          if $dev_env.has_direnv or not $dev_env.has_flake {
              ^sh -c 'exec hx .'
              cd $cwd
              nu --login
          } else {
              ^nix develop ($dev_env.dev_shell) -c sh -c 'exec hx .'
              cd $cwd
              nu --login
          }
      }

      # NixOS flake management (uses nh for nice diffs and colored output)
      # Also supports: flake init <template> to scaffold a new project from this
      # flake's `templates` output (sources under ${dirs.templates})
      def flake [
          action: string = "switch"                          # switch, boot, test, build, dry, update, rollback, init
          template?: string                                  # template name for init (e.g. rust-cli, rust-gui)
          --update (-u)                                      # update flake inputs first
          --dir (-d): string = "${dirs.nixosConfig}"           # flake directory
          --remote (-r)                                      # build on homeserver, then pull via its cache
      ] {
          if $action == "init" {
              let templates_dir = ("${dirs.templates}" | path expand)
              if ($template == null) {
                  print "Available templates:"
                  ls $templates_dir | where type == dir | get name | each { |d| print $"  - ($d | path basename)" }
                  return
              }
              let template_path = ($templates_dir | path join $template)
              if not ($template_path | path exists) {
                  print $"(ansi red)Template '($template)' not found.(ansi reset)"
                  print "Available templates:"
                  ls $templates_dir | where type == dir | get name | each { |d| print $"  - ($d | path basename)" }
                  return
              }
              # The templates are outputs of the root flake; templates/ itself
              # has no flake.nix, so it is only listed, never referenced.
              nix flake init --template $"("${dirs.nixosConfig}" | path expand)#($template)"
              print $"(ansi green)Initialized flake from template '($template)'.(ansi reset)"
              return
          }

          let flake_dir = ($dir | path expand)

          # Check for unstaged changes — flakes only see git-added files
          let not_added = (git -C $flake_dir diff --name-only | str trim)
          let untracked = (git -C $flake_dir ls-files --others --exclude-standard | str trim)
          let unadded = ([$not_added $untracked] | where ($it | is-not-empty) | str join "\n")
          if ($unadded | is-not-empty) {
              print $"(ansi yellow)Warning: these files are not staged and will be invisible to the flake:(ansi reset)"
              print ((ansi dark_gray) + $unadded + (ansi reset))
              let answer = (input $"(ansi yellow)Continue anyway? [y/N] (ansi reset)")
              if ($answer | str lowercase) != "y" {
                  print "Aborted."
                  return
              }
          }

          if $update or $action == "update" {
              print $"(ansi cyan)Updating flake inputs...(ansi reset)"
              nix flake update --flake $flake_dir
              if $action == "update" {
                  return
              }
          }

          if $action == "rollback" {
              print $"(ansi yellow)Rolling back to previous generation...(ansi reset)"
              sudo nixos-rebuild switch --rollback
              return
          }

          # Push-build-pull: ship the staged tree plus every locked input to
          # the homeserver's store, realise this host's toplevel there, then
          # let the local nh run below find it all in harmonia (port 5001,
          # see modules/system/core/nix-caches.nix) and only download +
          # activate. Evaluation happens on both ends, but nothing in the
          # config depends on self.rev, so both produce the same drv paths
          # and the substituter lookup hits. No sudo and no root ssh key: the
          # far side is the homeserver's `nix-remote` account (a trusted Nix
          # user and nothing else, see hosts/homeserver), reached with this
          # user's own key.
          if $remote {
              if $action not-in ["switch" "boot" "test" "build"] {
                  print $"(ansi red)Remote build only supports: switch, boot, test, build(ansi reset)"
                  return
              }
              let host = (sys host | get hostname)
              let builder = "nix-remote@homeserver"
              # gcroot on the homeserver so a later GC doesn't evict the
              # generation before another machine (or a reinstall) pulls it.
              # `~` is expanded by the remote shell, so this lands in
              # nix-remote's own home; nu leaves it literal.
              let out_link = $"~/.local/state/nix-builds/($host)"
              let archived = (try {
                  print $"(ansi cyan)Copying flake source and inputs to homeserver...(ansi reset)"
                  nix flake archive --to $"ssh-ng://($builder)" --json $flake_dir | from json
              } catch {
                  print $"\n(ansi yellow)Copying to homeserver failed.(ansi reset)"
                  null
              })
              if $archived == null { return }
              let src = ($archived | get path)
              print $"(ansi cyan)Building ($host) on homeserver...(ansi reset)"
              let built = (try {
                  # -t: a tty on the far side keeps nix's progress bar and colors.
                  ssh -t $builder $"mkdir -p ~/.local/state/nix-builds && nix build --print-build-logs --out-link ($out_link) 'path:($src)#nixosConfigurations.($host).config.system.build.toplevel'"
                  true
              } catch {
                  print $"\n(ansi yellow)Remote build interrupted or failed.(ansi reset)"
                  false
              })
              if not $built { return }
              print $"(ansi cyan)Pulling from homeserver cache and running ($action) locally...(ansi reset)"
          }

          let nh_action = if $action == "dry" { "build" } else { $action }
          let nh_args = if $action == "dry" { ["--dry"] } else { [] }

          try {
              nh os $nh_action $flake_dir ...$nh_args
          } catch {
              print $"\n(ansi yellow)Build interrupted or failed.(ansi reset)"
          }
      }

      # Enter nix develop shell in current terminal only
      def enter [shell?: string] {
          # Check if .envrc exists - if so, direnv will handle it
          if ('.envrc' | path exists) {
              print "Using direnv environment (found .envrc)"
              # direnv will auto-load when we spawn a new shell
              nu --login
          } else if ($shell == "nu") {
              ^nix develop .#default -c nu --login
          } else if ($shell == null) {
              nix develop .#default
          } else {
              nix develop .#($shell)
          }
      }

      # Run the dev layout setup, which needs a niri session to drive
      def compositorDevSetup [] {
          if ("NIRI_SOCKET" in $env) {
              niriDevSetup
          } else {
              print "No niri session detected (NIRI_SOCKET unset)"
          }
      }

      # Smart project development with automatic discovery
      def dev [project?: string] {
          if ($project == null) {
              compositorDevSetup
          } else {
              let projects_dir = ("${dirs.projects}" | path expand)

              # Search for project in language subdirectories
              let found_project = (
                  ls $projects_dir
                  | where type == dir
                  | get name
                  | each { |lang_dir|
                      let project_path = $"($lang_dir)/($project)"
                      if ($project_path | path exists) {
                          $project_path
                      } else {
                          null
                      }
                  }
                  | compact
                  | first
              )

              let work_dir = if ($project | path exists) {
                  $project | path expand
              } else if ($found_project != null) {
                  $found_project | path expand
              } else {
                  let base = ("${dirs.projects}" | path expand)
                  $"($base)/($project)" | path expand
              }
              cd $work_dir
              compositorDevSetup
          }
      }

      # The `[[package]]` stanza for reedline, blocks being blank-line separated
      def reedlineBlock [lock: string] {
          let hits = ($lock | split row "\n\n" | where {|b| $b | str starts-with "[[package]]\nname = \"reedline\"\n" })
          if ($hits | is-empty) { "" } else { $hits | first }
      }

      def blockRev [block: string] {
          let revs = ($block | parse --regex '#(?<rev>[0-9a-f]{40})' | get rev)
          if ($revs | is-empty) { "?" } else { $revs | first | str substring 0..<7 }
      }

      # Move reedline's pin in the nushell repo to its branch head. A plain
      # `cargo update -p reedline` also rewrites ~26 lines of windows-sys edges,
      # since rustix, tempfile and friends accept `>=0.52, <0.62` and every lock
      # rewrite collapses them onto the oldest locked version. That drift is
      # unrelated to the bump, so keep reedline's block and drop the rest.
      def bump-reedline [] {
          let repo = (^git rev-parse --show-toplevel | complete)
          let root = ($repo.stdout | str trim)
          if $repo.exit_code != 0 or ($root | path basename) != "nushell" {
              print $"(ansi red)Not in the nushell repo.(ansi reset)"
              return
          }

          cd $root
          let lock = ($root | path join "Cargo.lock")
          let old = (reedlineBlock (open --raw $lock))
          if ($old | is-empty) {
              print $"(ansi red)Cargo.lock has no git-pinned reedline.(ansi reset)"
              return
          }

          ^cargo update -p reedline
          let new = (reedlineBlock (open --raw $lock))

          ^git checkout -- $lock
          let patched = (open --raw $lock | str replace $old $new)
          $patched | save -f $lock

          if $old == $new {
              print $"(ansi yellow)reedline already at (blockRev $old)(ansi reset)"
          } else {
              print $"(ansi green)reedline (blockRev $old) -> (blockRev $new)(ansi reset)"
          }
      }
    '';
  };

  programs.nushell = {
    enable = true;

    extraEnv = builtins.readFile ./nushell/extra_env.nu;

    extraConfig = lib.mkMerge [
      (
        # cl.nu first: development.nu calls `cl-matches`, and nushell binds
        # command names at parse time, so a def sourced later would be taken
        # for an external command.
        ''
          source ~/.config/nushell/cl.nu
          source ~/.config/nushell/fetch.nu
        ''
        + (lib.optionalString hasTerminal ''
          source ~/.config/nushell/development.nu
        '')
        + builtins.readFile ./nushell/extra_config.nu
        # After the base record, which it writes into. Replaces the carapace
        # module's own nushell integration; see programs.carapace below.
        + "\n"
        + builtins.readFile ./nushell/carapace.nu
        # Layer the edit mode on after the base record. Requires the
        # upstream-main nushell from the shared overlay; nixpkgs' release
        # doesn't know `helix` yet and hard-errors at startup on it.
        + ''

          $env.config.edit_mode = 'helix'
          $env.config.cursor_shape = ($env.config.cursor_shape | merge {
            helix_normal: block
            helix_select: underscore
            helix_insert: line
          })
        ''
        # Visual/select highlight, generated so it tracks the palette. helix
        # renders ui.selection as `gray` (base16_transparent), which ansi.nix
        # maps to base03, so pinning both keys here keeps the shell and the
        # editor on one selection color.
        #
        # Both get the same bg on purpose: the cell under the cursor is set
        # apart by the terminal cursor shape, not by a second shade. `attr: n`
        # clears nushell's default reverse video on selection_cursor, which
        # would otherwise invert the fg/bg of that one cell, and leaving `fg`
        # unset on both keeps selected text in its syntax color.
        + ''

          $env.config.color_config.selection = { bg: "#${config.scheme.base03}" }
          $env.config.color_config.selection_cursor = { attr: n, bg: "#${config.scheme.base03}" }
        ''
      )

      # Make the prompt itself end in a newline, so *every* indicator reedline
      # can swap in (vi mode, reverse-search, menu markers) starts on line two.
      # Only the vi indicators are configurable; nushell hardcodes the other two
      # without a leading newline, so carrying it there left them rendering on
      # the Starship row.
      #
      # mkAfter since starship's enableNushellIntegration writes into this same
      # option and its export-env `load-env` installs PROMPT_COMMAND, so we can
      # only wrap the closure once that has run.
      #
      # The "\n" has to be appended in nushell rather than via starship's
      # `format`, since nushell strips one trailing newline off external command
      # output and would eat it.
      (lib.mkAfter ''

        let starship_prompt = $env.PROMPT_COMMAND
        $env.PROMPT_COMMAND = {|| (do $starship_prompt) + "\n" }
      '')
    ];

    shellAliases =
      {
        cd = "z";
        cat = "bat";
        rip = "rip --graveyard ($env.HOME)/.local/share/Trash";
      }
      // lib.optionalAttrs hasTerminal {
        icat = "chafa";
      };
  };

  programs.carapace = {
    enable = true;
    # The snippet this would source (`carapace _carapace nushell`) still
    # declares the legacy `{|spans| ...}` completer, deprecated on nushell
    # main. ./nushell/carapace.nu wires carapace up on the named inputs
    # instead; see the comment there.
    enableNushellIntegration = false;
  };

  programs.starship = {
    enable = true;
    enableNushellIntegration = true;

    settings =
      lib.recursiveUpdate
      # Nerd-font symbols preset, taken out of the very starship being
      # installed: nixpkgs puts every preset under share/starship/presets, so
      # the symbols and the binary that reads them come from one derivation and
      # cannot disagree. Carrying the preset separately is what made them
      # disagree before, whether as a flake input or vendored here: upstream
      # only publishes it from master, which runs ahead of the release nixpkgs
      # packages, thus starship warned `Unknown key` on every prompt for each
      # module it did not have yet (`jj_bookmark`, starship#7643, most
      # recently). Nothing to refresh now, and nothing to prune per release.
      #
      # This reads a file out of a derivation, so eval realises the starship
      # package before the build graph exists, and evaluating a host of another
      # architecture substitutes that host's starship on whichever machine
      # evaluates. Worth it for a cached ~5MB package that every host installs
      # anyway; it would not be for anything that has to be compiled.
      #
      # `maven` and `os` are dropped as modules we don't run, the os table
      # being ~60 symbols for one that is off by default.
      (builtins.removeAttrs
        (builtins.fromTOML (builtins.readFile
            "${config.programs.starship.package}/share/starship/presets/nerd-font-symbols.toml"))
        ["maven" "os"])
      {
        command_timeout = 2000;
        # Single-line module row. `$all` is every module in default order, which
        # *includes* a `$line_break` (after cmd_duration, pushing time/status to
        # a 2nd line) and a trailing `$character` caret. Disable both: line_break
        # so all modules stay on one row, character to drop the caret. The real
        # 2nd line (the input line) comes from the PROMPT_COMMAND wrapper above,
        # which appends the newline in nushell. Don't move that newline into this
        # format string: nushell strips one trailing newline off external command
        # output, so starship's own would never reach reedline.
        format = "$all";
        line_break.disabled = true;
        character.disabled = true;
        # Relabel long, uninteresting paths to short names (git-repo-like).
        # Applied before truncation, so the label only survives within
        # `truncation_length` (default 3) folders of the root — same as how
        # Starship shows a real repo's name. Matches against the ~-contracted
        # path, so the key must start with ~, not /home/...
        directory.substitutions = {
          "${dirs.vault}" = "vault";
        };
        git_status = {
          ahead = "↑";
          behind = "↓";
          diverged = "↕";
        };
        git_branch.symbol = " ";
        nix_shell = {
          impure_msg = "";
          pure_msg = "pure";
          format = "via [$symbol$state( $name)](bold blue) ";
        };
        time = {
          disabled = false;
          format = "at [$time]($style) ";
          time_format = "%R";
        };
      };
  };
}
