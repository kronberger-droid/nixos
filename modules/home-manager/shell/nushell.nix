{
  pkgs,
  config,
  lib,
  options,
  inputs,
  ...
}: let
  hasTerminal = options ? terminal;
  # The nushell overlay's plugin, absent from a package set that does not
  # carry that overlay's nushell (droid). It decides who draws the prompt.
  hasGstat = pkgs ? nu_plugin_gstat;

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

  # LS_COLORS from the base16 scheme. Left unset, nushell falls back to a
  # built-in table of 256-color indices (38;5;N), which the terminal palette
  # in theming/ansi.nix never touches, so `ls` names, `grid -c` and path
  # completions ignored the theme. Truecolor rather than the 16 ANSI codes so
  # the string carries the scheme itself and reads the same in a terminal
  # that was not themed from it. Hues follow the dircolors conventions.
  lsColors = let
    s = config.scheme;
    rgb = slot: "${s."${slot}-rgb-r"};${s."${slot}-rgb-g"};${s."${slot}-rgb-b"}";
    fg = slot: "38;2;${rgb slot}";
    bg = slot: "48;2;${rgb slot}";
    exts = style: map (ext: "*.${ext}=${style}");
  in
    lib.concatStringsSep ":" (
      [
        "no=0"
        "fi=0"
        "di=${fg "base0D"}"
        "ln=${fg "base0C"}"
        "ex=1;${fg "base0B"}"
        # Broken links and their missing targets.
        "or=${fg "base08"}"
        "mi=${fg "base08"}"
        "so=${fg "base0E"}"
        "pi=${fg "base0E"}"
        "bd=${fg "base0A"}"
        "cd=${fg "base0A"}"
        "su=${fg "base00"};${bg "base08"}"
        "sg=${fg "base00"};${bg "base0A"}"
        # Sticky and other-writable directories stay plain directories:
        # /tmp and every mounted share would otherwise shout.
        "st=${fg "base0D"}"
        "tw=${fg "base0D"}"
        "ow=${fg "base0D"}"
        "*~=${fg "base03"}"
      ]
      ++ exts (fg "base03") ["bak" "orig" "swp" "tmp" "lock" "log" "pyc" "o"]
      ++ exts (fg "base0A") ["tar" "tgz" "gz" "xz" "zst" "bz2" "zip" "7z" "rar" "iso" "deb" "rpm"]
      ++ exts (fg "base0E") [
        "png"
        "jpg"
        "jpeg"
        "gif"
        "webp"
        "svg"
        "avif"
        "mp4"
        "mkv"
        "webm"
        "mov"
        "mp3"
        "flac"
        "ogg"
        "opus"
        "wav"
      ]
    );
in {
  home.packages = with pkgs; [
    gitui
  ];

  xdg.configFile."nushell/fetch.nu".source = ./nushell/fetch.nu;
  xdg.configFile."nushell/heat.nu".source = ./nushell/heat.nu;
  # Plain .nu with @name@ placeholders, so it stays lintable; replaceVars fails
  # the build on one left unfilled.
  xdg.configFile."nushell/prompt.nu".source = pkgs.replaceVars ./nushell/prompt.nu {
    vault = dirs.vault;
  };

  # Generated so it can use centralised path variables
  xdg.configFile."nushell/utilities.nu".text = ''
    # Utility functions for various tasks

    # Quick Q&A using Claude Haiku — pipe a question or pass directly.
    # The question travels as an argument: for the primary user `claude`
    # crosses into the sandbox through a pty (security/claude-enter.nu),
    # which is no place to send a pipe.
    def ask [question?: string] {
        let q = if ($question | is-not-empty) { $question } else { $in }
        claude -p --model haiku --system-prompt "Answer in 1-3 concise sentences. Be direct, no preamble." $q
    }

    # Kept from when `cl` was the sandbox launcher and `claude` ran here.
    alias cl = claude

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

    # Devices Taildrop can reach right now (offline ones left out)
    def send-targets [] {
        ^tailscale file cp --targets | lines | where $it !~ offline | split column "\t" ip name | get name
    }

    # Send files to one of your own devices over Taildrop: send nothing a.pdf
    def send [
        device: string@send-targets   # device name from `tailscale status`
        ...files: path                # what to send
    ] {
        if ($files | is-empty) { error make {msg: "no files to send"} }
        ^tailscale file cp ...($files | path expand) $"($device):"
    }

    # Fetch what is waiting in Taildrop now. The taildrop-receive service does
    # this on its own as files arrive; this is for a host without it.
    def receive [] {
        ^tailscale file get --conflict=rename ($nu.home-path | path join Downloads)
    }

    # Launch a GUI app detached from this shell — survives closing the terminal
    def detach [...cmd: string] {
        ^setsid -f ...$cmd out> /dev/null err> /dev/null
    }

    # Open Obsidian on a folder, the current one by default. A folder inside
    # a vault opens that vault. Any other folder becomes a new vault: the
    # obsidian:// URI only reaches vaults Obsidian already lists, so the
    # folder is added to that list first. Obsidian is a Flatpak that sees
    # only the notes tree, ~/Projects and Downloads (apps/flatpak.nix).
    def obsidian [dir: path = "."] {
        let app = "md.obsidian.Obsidian"
        let target = ($dir | path expand)
        if ($target | path type) != "dir" {
            error make {msg: $"not a directory: ($target)"}
        }
        let list = ($nu.home-dir | path join .var app $app config obsidian obsidian.json)
        if not ($list | path exists) {
            error make {msg: $"no vault list at ($list); start Obsidian once first"}
        }
        let state = (open --raw $list | from json)
        let vaults = ($state.vaults? | default {})

        # The nearest ancestor holding .obsidian, else the folder itself.
        let parts = ($target | path split)
        let root = (
            ($parts | length)..1
            | each {|n| $parts | first $n | path join }
            | where {|p| $p | path join .obsidian | path exists }
            | get 0?
            | default $target
        )

        let known = ($vaults | transpose id vault | where {|v| $v.vault.path == $root })
        let id = if ($known | is-not-empty) {
            $known.0.id
        } else {
            # A running Obsidian keeps the list in memory: it would not find
            # the new vault and would write the entry away on its next save.
            if $app in (^flatpak ps --columns=application | lines) {
                error make {msg: $"($root) is not a vault yet and Obsidian is running; quit it and run this again"}
            }
            let id = (random binary 8 | encode hex | str lowercase)
            let entry = {path: $root, ts: (date now | format date "%s%3f" | into int)}
            $state | upsert vaults ($vaults | insert $id $entry) | to json | save -f $list
            $id
        }
        detach flatpak run $app $"obsidian://open?vault=($id)"
    }

    # Pick a color from the screen with niri's built-in picker and copy the
    # hex to the clipboard. Escape cancels; niri then prints null.
    def color-picker [] {
        let picked = (niri msg -j pick-color | from json)
        if $picked == null { return }
        let rgb = ($picked.rgb | each {|c| $c * 255 | math round | into int })
        let hex = ($rgb
            | each {|c| $c | format number | get lowerhex | str substring 2.. | fill --alignment right --width 2 --character '0' }
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
              # hasAttr, so the probe names the shell without instantiating it.
              let probe = (^nix eval .#devShells.x86_64-linux --apply 'builtins.hasAttr "dev"' | complete)
              if $probe.exit_code == 0 and ($probe.stdout | str trim) == "true" {
                  ".#dev"
              } else {
                  ".#default"
              }
          } else {
              ""
          }
          { has_direnv: $has_direnv, has_flake: $has_flake, dev_shell: $dev_shell }
      }

      # One word for sh, whatever is in it: the strings built below go
      # through `sh -c`, and a directory name may hold spaces or worse.
      def shq [word: string] {
          let q = (char single_quote)
          $q + ($word | str replace --all $q $"($q)\\($q)($q)") + $q
      }

      # Open the terminal in a directory and run a command there. `cmd` is
      # sh text, the directory is not.
      def termIn [cwd: string, cmd: string] {
          $"${config.terminal.bin} ${config.terminal.workingDirFlag}=(shq $cwd) ${config.terminal.execFlag} ($cmd)"
      }

      # Build a terminal command string with optional dev shell wrapping
      def termCmd [cwd: string, dev_env: record, exec_args: string] {
          if $dev_env.has_direnv or not $dev_env.has_flake {
              termIn $cwd $exec_args
          } else {
              termIn $cwd $"nix develop ($dev_env.dev_shell) -c ($exec_args)"
          }
      }

      # Build a claude terminal command string. No local dev shell around
      # it: `claude` crosses into the sandbox (security/claude-enter.nu),
      # which finds its checkout of this repo and builds its own.
      def claudeCmd [cwd: string] {
          termIn $cwd "claude"
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
              ^niri msg action spawn -- sh -c (termCmd $cwd $dev_env $"typst watch (shq $"($cwd)/main.typ") (shq $"($cwd)/main.pdf")")
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
              ^niri msg action spawn -- sh -c (claudeCmd $cwd)
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
              ^niri msg action spawn -- sh -c (claudeCmd $cwd)
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

    # Exported, so eza, fd and anything else reading LS_COLORS follows too.
    environmentVariables.LS_COLORS = lsColors;

    # Git status for a prompt in one call to a process that stays up, instead
    # of spawning git. Guarded since the package only exists where the nushell
    # overlay provides it (not on droid, see nushell-overlay.nix). The
    # registry this writes is a store path, so `plugin add` by hand fails
    # with a read-only error: add plugins here.
    plugins = lib.optionals hasGstat [pkgs.nu_plugin_gstat];

    extraEnv = builtins.readFile ./nushell/extra_env.nu;

    extraConfig = lib.mkMerge [
      (
        ''
          source ~/.config/nushell/fetch.nu
          source ~/.config/nushell/heat.nu
        ''
        + (lib.optionalString hasTerminal ''
          source ~/.config/nushell/development.nu
        '')
        + builtins.readFile ./nushell/extra_config.nu
        # After the base record, which it writes into. Replaces the carapace
        # module's own nushell integration; see programs.carapace below.
        + "\n"
        + builtins.readFile ./nushell/carapace.nu
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

      # The prompt. Where the gstat plugin exists it is nushell's own, from
      # ./nushell/prompt.nu; elsewhere (droid) starship draws the live prompt as
      # before. Either way a submitted prompt collapses to `prompt transient`.
      #
      # The prompt ends in a newline, so *every* indicator reedline can swap in
      # (vi mode, reverse-search, menu markers) starts on line two. Only the vi
      # indicators are configurable; nushell hardcodes the other two without a
      # leading newline, so carrying it there left them rendering on the module
      # row. For starship the "\n" has to be appended here rather than in its
      # `format`, since nushell strips one trailing newline off external
      # command output and would eat it.
      #
      # mkAfter since starship's enableNushellIntegration writes into this same
      # option and its export-env `load-env` installs PROMPT_COMMAND, so we can
      # only wrap the closure once that has run.
      (lib.mkAfter (''

          use ~/.config/nushell/prompt.nu
        ''
        + (
          if hasGstat
          then ''
            $env.PROMPT_COMMAND = {|| prompt left }
            $env.PROMPT_COMMAND_RIGHT = {|| prompt right }
            # What starship's init used to set alongside its prompt: no
            # indicator of the prompt's own, its continuation mark, and the
            # right side on the input line (see `right_format` below for why
            # that row).
            $env.PROMPT_INDICATOR = ""
            $env.PROMPT_MULTILINE_INDICATOR = $"(ansi dark_gray)∙(ansi reset) "
            $env.config.render_right_prompt_on_last_line = true
          ''
          else ''
            let starship_prompt = $env.PROMPT_COMMAND
            $env.PROMPT_COMMAND = {|| (do $starship_prompt) + "\n" }
          ''
        )
        + ''
          $env.TRANSIENT_PROMPT_COMMAND = {|| prompt transient }
          # Unset, the collapsed line would keep the live right prompt.
          $env.TRANSIENT_PROMPT_COMMAND_RIGHT = ""
        ''))
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
    # Only where nushell has no prompt of its own, see `hasGstat`: that is
    # droid. Everywhere else nothing would call it, since no host runs it in
    # bash, so it is not installed there and the settings below are never
    # evaluated, the preset read out of its package included.
    enable = !hasGstat;
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
        # The module row holds what should survive a slim terminal: where you
        # are, what git says, and the package version for release work. Every
        # other module goes to the right prompt, where `$all` means "all that
        # `format` did not name". starship's nu init sets
        # `render_right_prompt_on_last_line`, so the right side sits on the
        # input line and reedline hides it once the typing reaches it: it can
        # neither wrap the module row nor collide with it. Turned off, it
        # would land on the blank spacer row (`add_newline`) instead, since
        # that row is the prompt's first.
        #
        # `$all` *includes* a `$line_break` and a trailing `$character` caret.
        # Disable both: a line break has no place in a right prompt, and the
        # caret is dropped. The real 2nd line (the input line) comes from the
        # PROMPT_COMMAND wrapper above, which appends the newline in nushell.
        # Don't move that newline into this format string: nushell strips one
        # trailing newline off external command output, so starship's own
        # would never reach reedline.
        format = "$username$hostname$directory$git_branch$git_commit$git_state$git_status$package";
        right_format = "$all";
        line_break.disabled = true;
        character.disabled = true;
        # Nothing shortens the left row once directory and branch alone
        # outgrow the terminal, so cap the one part with no natural limit.
        git_branch.truncation_length = 32;
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
        # The row reads by weight: where you are and what git says stay bold,
        # versions and the rest drop to plain color. The stock formats are
        # restated for that, connectives ("on", "is", "via") included: the row
        # reads as a sentence with them. Only the modules for what gets worked
        # on here are restated; any other language keeps starship's stock look.
        git_branch.format = "on [$symbol$branch(:$remote_branch)]($style) ";
        # The tag sitting on HEAD, on a branch too, so a release commit shows
        # its tag beside the package version. Stock only shows this module on
        # a detached HEAD, with the hash; the hash is given up for the tag.
        git_commit = {
          only_detached = false;
          tag_disabled = false;
          tag_symbol = " ";
          format = "[($tag )]($style)";
          style = "green";
        };
        # Stock is `208 bold`, a 256-color index the terminal palette does
        # not remap.
        package = {
          format = "is [$symbol$version]($style) ";
          style = "yellow";
        };
        rust = {
          format = "via [$symbol($version )]($style)";
          style = "red";
        };
        python = {
          format = "via [\${symbol}\${pyenv_prefix}(\${version} )(\\($virtualenv\\) )]($style)";
          style = "yellow";
        };
        # c, cpp and typst are stock 256-color or hex, off the scheme.
        c = {
          format = "via [$symbol($version(-$name) )]($style)";
          style = "green";
        };
        cpp = {
          format = "via [$symbol($version(-$name) )]($style)";
          style = "green";
        };
        cmake = {
          format = "via [$symbol($version )]($style)";
          style = "blue";
        };
        typst = {
          format = "via [$symbol($version )]($style)";
          style = "cyan";
        };
        nix_shell = {
          impure_msg = "";
          pure_msg = "pure";
          format = "via [$symbol$state( $name)](blue) ";
        };
        cmd_duration = {
          # Stock but for the weight.
          format = "< took [$duration]($style) ";
          style = "yellow";
        };
        # No `time`: a clock on the live prompt says when the prompt was
        # drawn. The transient prompt above stamps each command as it is
        # submitted, which is the time worth having in scrollback.
      };
  };
}
