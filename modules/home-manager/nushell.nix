{
  pkgs,
  config,
  lib,
  ...
}: {
  home.packages = with pkgs; [
    bat
    zoxide
    lazygit
    rip2
    navi
    tealdeer
    zellij
  ];

  # Generate development.nu with dynamic terminal configuration
  xdg.configFile."nushell/development.nu".text = ''
    # Development environment setup and utilities

    # Sway development layout setup
    def swayDevSetup [] {
        print "Setting up Sway development layout..."
        # Get current working directory
        let cwd = $env.PWD

        # Check if direnv is active
        let has_direnv = ('.envrc' | path exists)

        # Detect dev shell (only if not using direnv)
        let dev_shell = if not $has_direnv {
            try {
                ^nix eval --json .#devShells.x86_64-linux.dev err> /dev/null
                ".#dev"
            } catch {
                ".#default"
            }
        } else {
            ""
        }

        ^swaymsg layout splith
        ^swaymsg layout stacking

        # Open shell terminal (will stack with original)
        if $has_direnv {
            print "Using direnv environment (found .envrc)"
            ^swaymsg exec $"${config.terminal.bin} ${config.terminal.workingDirFlag}=($cwd) ${config.terminal.execFlag} nu --login"
        } else {
            ^swaymsg exec $"${config.terminal.bin} ${config.terminal.workingDirFlag}=($cwd) ${config.terminal.execFlag} nix develop ($dev_shell) -c nu --login"
        }
        sleep 500ms

        # Focus back to original terminal
        ^swaymsg focus parent

        # Open Claude terminal - enter shell and run claude
        if $has_direnv {
            ^swaymsg exec $"${config.terminal.bin} ${config.terminal.workingDirFlag}=($cwd) ${config.terminal.execFlag} sh -c 'exec claude'"
        } else {
            ^swaymsg exec $"${config.terminal.bin} ${config.terminal.workingDirFlag}=($cwd) ${config.terminal.execFlag} nix develop ($dev_shell) -c sh -c 'exec claude'"
        }
        sleep 500ms

        # Move Claude to the right side
        ^swaymsg layout stacking
        ^swaymsg focus left

        # Enter dev shell in current terminal and open helix
        if $has_direnv {
            ^sh -c 'exec hx .'
            cd $cwd
            nu --login
        } else {
            ^nix develop ($dev_shell) -c sh -c 'exec hx .'
            cd $cwd
            nu --login
        }
    }

    # NixOS flake management
    def flake [
        action: string = "switch"                          # switch, boot, test, build, dry, update, rollback
        --update (-u)                                      # update flake inputs first
        --dir (-d): string = "~/.config/nixos"             # flake directory
        --yes (-y)                                         # skip confirmation on dirty tree
    ] {
        let flake_dir = ($dir | path expand)
        let hostname = (hostname)

        # Check for unstaged changes
        let unstaged = (git -C $flake_dir status --porcelain | lines | where {|l| ($l | str length) > 0 and not ($l | str starts-with "A ") and not ($l | str starts-with "M ")})
        if ($unstaged | length) > 0 {
            print $"(ansi yellow_bold)Warning:(ansi reset) Untracked/unstaged files:"
            $unstaged | each {|f| print $"  (ansi dark_gray)($f)(ansi reset)"}
            print ""
            if not $yes {
                let answer = (input $"(ansi yellow)Continue anyway? [y/N] (ansi reset)")
                if ($answer | str downcase) != "y" {
                    print "Aborted."
                    return
                }
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

        let cmd = if $action == "dry" { "dry-activate" } else { $action }
        print $"(ansi green_bold)Rebuilding:(ansi reset) ($hostname) [($cmd)]"
        try {
            sudo nixos-rebuild $cmd --flake $"($flake_dir)#($hostname)"
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

    # Smart project development with automatic discovery and Sway setup
    def dev [project?: string] {
        if ($project == null) {
            swayDevSetup
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
            swayDevSetup
        }
    }
  '';

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
      // lib.optionalAttrs config.terminal.hasKittens {
        icat = "kitten icat";
        ssh = "kitty +kitten ssh";
      };
  };

  programs.starship = {
    enable = true;
    enableNushellIntegration = true;

    settings =
      (with builtins; fromTOML (readFile "${pkgs.starship}/share/starship/presets/nerd-font-symbols.toml"))
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
