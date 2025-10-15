# Development environment setup and utilities

# Sway development layout setup
def swayDevSetup [] {
    print "Setting up Sway development layout..."
    # Get current working directory
    let cwd = $env.PWD
    # Detect dev shell
    let dev_shell = try {
        ^nix eval --json .#devShells.x86_64-linux.dev err> /dev/null
        ".#dev"
    } catch {
        ".#default"
    }
    ^swaymsg layout splith
    ^swaymsg layout stacking
    
    # Open shell terminal (will stack with original)
    ^swaymsg exec $"kitty --working-directory=($cwd) -e nix develop ($dev_shell) -c nu --login"
    sleep 500ms
    
    # Focus back to original terminal
    ^swaymsg focus parent
    
    # Open Claude terminal - enter shell and run claude
    ^swaymsg exec $"kitty --working-directory=($cwd) -e nix develop ($dev_shell) -c sh -c 'exec claude'"
    sleep 500ms
    
    # Move Claude to the right side
    ^swaymsg layout stacking
    ^swaymsg focus left
    
    # Enter dev shell in current terminal and open helix
    ^nix develop ($dev_shell) -c sh -c 'exec hx .'
    cd $cwd
    nu --login
}

# Quick flake rebuild for current hostname
def flake-reload [] {
    let hostname = (hostname)
    git add .
    sudo nixos-rebuild switch --flake ~/.config/nixos#($hostname)
}

# Enter nix develop shell in current terminal only
def enter [] {
    nix develop .#default
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

