{
  pkgs,
  config,
  lib,
  options,
  ...
}: let
  hasTerminal = options ? terminal;
in {
  home.packages = with pkgs; [
    bat
    zoxide
    lazygit
    rip2
    navi
    tealdeer
    zellij
  ];

  xdg.configFile."nushell/utilities.nu".source = ./nushell/utilities.nu;
  xdg.configFile."nushell/keybindings.nu".source = ./nushell/keybindings.nu;

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
    def flake [
        action: string = "switch"                          # switch, boot, test, build, dry, update, rollback
        --update (-u)                                      # update flake inputs first
        --dir (-d): string = "~/.config/nixos"             # flake directory
    ] {
        let flake_dir = ($dir | path expand)

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
            let projects_dir = $env.HOME + "/Programming"

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
                $"($env.HOME)/($project)" | path expand
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
        rm = "echo 'use rip instead'";
        tldr = "tealdeer";
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
      (with builtins; fromTOML (readFile ./nerd-font-symbols.toml))
      // {
        command_timeout = 2000;
        git_branch.symbol = " ";
        time = {
          disabled = false;
          format = "[$time]($style) ";
        };
      };
  };
}
