{
  pkgs,
  config,
  lib,
  options,
  inputs,
  ...
}: let
  hasTerminal = options ? terminal;

  # Centralised personal directory paths — change here, updates everywhere
  dirs = {
    nixosConfig = "~/.config/nixos";
    templates = "~/.config/nixos/templates";
    projects = "~/Programming";
    emulation = "~/Emulation";
  };
in {
  home.packages = with pkgs; [
    gitui
    navi
  ];

  xdg.configFile."nushell/keybindings.nu".source = ./nushell/keybindings.nu;

  # Generated so it can use centralised path variables
  xdg.configFile."nushell/utilities.nu".text = ''
    # Utility functions for various tasks

    # Quick Q&A using Claude Haiku — pipe a question or pass directly
    def ask [question?: string] {
        let q = if ($question | is-not-empty) { $question } else { $in }
        $q | claude -p --model haiku --system-prompt "Answer in 1-3 concise sentences. Be direct, no preamble."
    }

    # Screen color picker utility for Wayland/Sway
    def color-picker [] {
        echo "In 1 sec you can pick a color!"
        sleep 1sec

        let geometry = (slurp -p)

        let result = (grim -g $geometry -t ppm - | magick - -format '%[pixel:p{0,0}]' txt:-)

        let tokens = (
            $result
            | split row "\n"
            | compact --empty
            | get 1
            | split row " "
            | compact --empty
        )

        echo [[type value]; [RGB ($tokens | get 1 | str replace -ra "[()]" "")] [HEX ($tokens | get 2)] ]
    }

    # SSH connection shortcuts
    def connect [host: string] {
        let connections = {
            datalab: "martin.kronberger@cluster.datalab.tuwien.ac.at",
            asc4: "sumo_mk@vsc4.vsc.ac.at",
            asc5: "sumo_mk@vsc5.vsc.ac.at"
        }

        if ($host in $connections) {
            let target = ($connections | get $host)
            print $"Connecting to ($host) \(($target)\)..."
            ^ssh $target
        } else {
            print $"Error: Unknown host '($host)'"
            print "Available hosts:"
            $connections | columns | each { |h| print $"  - ($h)" }
        }
    }

    # QuickEMU VM management
    def emu [config?: string] {
        let emulation_dir = ("${dirs.emulation}" | path expand)
        let windows_dir = ($emulation_dir | path join "windows-10")

        # Check if windows-10 directory exists
        if not ($windows_dir | path exists) {
            print $"Error: QuickEMU windows-10 not initialized. Expected directory: ($windows_dir)"
            print $"Run 'quickget windows 10' in ($emulation_dir) first."
            return
        }

        # Check if disk image exists
        let disk_path = ($windows_dir | path join "disk.qcow2")
        if not ($disk_path | path exists) {
            print $"Error: Windows 10 disk image not found at: ($disk_path)"
            print $"Initialize the VM by running 'quickget windows 10' in ($emulation_dir)."
            return
        }

        # Determine which config to use
        let config_file = match $config {
            "default" => "windows-10-default.conf"
            "nanonis" => "windows-10-spm.conf"
            null => "windows-10-default.conf"
            _ => {
                print $"Error: Unknown config '($config)'. Available options: default, nanonis"
                return
            }
        }

        let config_path = ($emulation_dir | path join $config_file)

        # Check if config file exists
        if not ($config_path | path exists) {
            print $"Error: Config file not found: ($config_path)"
            print "Make sure you've run 'sudo nixos-rebuild switch --flake .' to deploy the configs."
            return
        }

        print $"Starting Windows 10 with ($config) config..."
        cd $emulation_dir
        quickemu --vm $config_file
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

      # Build a terminal command string with optional dev shell wrapping
      def termCmd [cwd: string, dev_env: record, exec_args: string] {
          if $dev_env.has_direnv or not $dev_env.has_flake {
              $"${config.terminal.bin} ${config.terminal.workingDirFlag}=($cwd) ${config.terminal.execFlag} ($exec_args)"
          } else {
              $"${config.terminal.bin} ${config.terminal.workingDirFlag}=($cwd) ${config.terminal.execFlag} nix develop ($dev_env.dev_shell) -c ($exec_args)"
          }
      }

      # Build a claude terminal command string
      def claudeCmd [cwd: string, dev_env: record] {
          if $dev_env.has_direnv or not $dev_env.has_flake {
              $"${config.terminal.bin} ${config.terminal.workingDirFlag}=($cwd) ${config.terminal.execFlag} sh -c 'exec claude'"
          } else {
              $"${config.terminal.bin} ${config.terminal.workingDirFlag}=($cwd) ${config.terminal.execFlag} nix develop ($dev_env.dev_shell) -c sh -c 'exec claude'"
          }
      }

      # Sway development layout setup
      def swayDevSetup [] {
          print "Setting up Sway development layout..."
          let cwd = $env.PWD
          let dev_env = detectDevEnv

          ^swaymsg layout splith
          ^swaymsg layout stacking

          ^swaymsg exec (termCmd $cwd $dev_env "nu --login")
          sleep 500ms

          ^swaymsg focus parent
          ^swaymsg exec (claudeCmd $cwd $dev_env)
          sleep 500ms

          ^swaymsg layout stacking
          ^swaymsg focus left

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

      # Niri development layout setup
      # Layout: left tabbed column = helix + shell, right column = claude
      # Typst: left tabbed column = helix + typst watch, right column = zathura
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
              # Spawn typst watch terminal (receives focus)
              ^niri msg action spawn -- sh -c (termCmd $cwd $dev_env $"typst watch ($cwd)/main.typ ($cwd)/main.pdf")
              sleep 500ms

              # Move typst watch into the tabbed column
              ^niri msg action consume-or-expel-window-left

              # Spawn zathura as the right column
              ^niri msg action spawn -- zathura ($cwd + "/main.pdf")
              sleep 500ms
          } else {
              # Spawn shell terminal (receives focus)
              ^niri msg action spawn -- sh -c (termCmd $cwd $dev_env "nu --login")
              sleep 500ms

              # Move shell into the tabbed column
              ^niri msg action consume-or-expel-window-left

              # Spawn Claude terminal as the right column
              ^niri msg action spawn -- sh -c (claudeCmd $cwd $dev_env)
              sleep 500ms
          }

          # Focus back to left column, top window (original terminal for helix)
          ^niri msg action focus-column-left
          ^niri msg action focus-window-up

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
      # Also supports: flake init <template> to scaffold a new project from ~/.config/nix-templates
      def flake [
          action: string = "switch"                          # switch, boot, test, build, dry, update, rollback, init
          template?: string                                  # template name for init (e.g. rust-cli, rust-gui)
          --update (-u)                                      # update flake inputs first
          --dir (-d): string = "${dirs.nixosConfig}"           # flake directory
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
              nix flake init --template $"path:($templates_dir)#($template)"
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
              if ($answer | str downcase) != "y" {
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

          let nh_action = if $action == "dry" { "build" } else { $action }
          let nh_args = if $action == "dry" { ["--dry"] } else { [] }

          try {
              $env.GIT_LFS_SKIP_SMUDGE = "1"
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

      # Detect compositor and run the appropriate dev setup
      def compositorDevSetup [] {
          if ("NIRI_SOCKET" in $env) {
              niriDevSetup
          } else if ("SWAYSOCK" in $env) {
              swayDevSetup
          } else {
              print "No supported compositor detected (checked NIRI_SOCKET, SWAYSOCK)"
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
    '';
  };

  programs.nushell = {
    enable = true;

    extraEnv = builtins.readFile ./nushell/extra_env.nu;

    extraConfig = builtins.readFile ./nushell/extra_config.nu;

    shellAliases =
      {
        cd = "z";
        cat = "bat";
        rip = "rip --graveyard ($env.HOME)/.local/share/Trash";
      }
      // lib.optionalAttrs (hasTerminal && config.terminal.hasKittens) {
        icat = "kitten icat";
        ssh = "kitty +kitten ssh";
      };
  };

  programs.starship = {
    enable = true;
    enableNushellIntegration = true;

    settings =
      lib.recursiveUpdate
      (builtins.removeAttrs (builtins.fromTOML (builtins.readFile inputs.starship-nerd-fonts)) ["maven"])
      {
        command_timeout = 2000;
        git_branch.symbol = " ";
        nix_shell = {
          impure_msg = "";
          pure_msg = "pure";
          format = "via [$symbol$state( $name)](bold blue) ";
        };
        time = {
          disabled = false;
          format = "[$time]($style) ";
        };
      };
  };
}
