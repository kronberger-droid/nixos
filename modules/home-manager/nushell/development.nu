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

# System maintenance commands
def system-cleanup [] {
    print "🧹 Running system cleanup..."

    print "📦 Collecting garbage (keeping last 3 generations)..."
    sudo nix-collect-garbage --delete-older-than 3d

    print "🔧 Optimizing Nix store..."
    sudo nix-store --optimise

    print "📝 Cleaning old journal logs..."
    sudo journalctl --vacuum-time=7d

    print "🗑️ Cleaning temporary files..."
    sudo find /tmp -type f -atime +7 -delete 2>/dev/null || true

    print "✅ System cleanup complete!"
}

# Deep system maintenance
def system-deep-clean [] {
    print "🔧 Running deep system maintenance..."

    print "📦 Aggressive garbage collection..."
    sudo nix-collect-garbage -d

    print "🔧 Optimizing Nix store..."
    sudo nix-store --optimise

    print "📊 Checking system integrity..."
    sudo nix-store --verify --check-contents

    print "📝 Cleaning all old logs..."
    sudo journalctl --vacuum-size=100M

    print "🔄 Rebuilding font cache..."
    fc-cache -f

    print "✅ Deep maintenance complete!"
}

# Check system health
def system-health [] {
    print "🏥 System Health Check"
    print "====================="

    print "\n📊 Disk Usage:"
    df -h / | tail -n 1

    print "\n💾 Memory Usage:"
    free -h

    print "\n🔥 Temperature:"
    try { sensors | grep "Core\|temp1" } catch { print "sensors not available" }

    print "\n📦 Nix Store Size:"
    du -sh /nix/store 2>/dev/null || print "Cannot access /nix/store"

    print "\n🗂️ Generation Count:"
    sudo nix-env --list-generations --profile /nix/var/nix/profiles/system | wc -l

    print "\n📝 Recent Journal Errors:"
    sudo journalctl --priority=err --since="24 hours ago" --no-pager | tail -n 5
}

# Update flake inputs
def flake-update [input?: string] {
    cd ~/.config/nixos
    if ($input != null) {
        print $"🔄 Updating ($input)..."
        nix flake update ($input)
    } else {
        print "🔄 Updating all flake inputs..."
        nix flake update
    }
    print "✅ Update complete!"
}

# Check what changed in the configuration
def system-diff [generation?: string] {
    let current_gen = if ($generation != null) { $generation } else { "current" }
    let previous_gen = if ($generation != null) { ($generation | into int) - 1 | into string } else { "previous" }

    print $"📋 Comparing ($previous_gen) -> ($current_gen)..."
    try {
        nvd diff /nix/var/nix/profiles/system-($previous_gen)-link /nix/var/nix/profiles/system-($current_gen)-link
    } catch {
        print "nvd not available, using nix-diff..."
        try {
            nix-diff /nix/var/nix/profiles/system-($previous_gen)-link /nix/var/nix/profiles/system-($current_gen)-link
        } catch {
            print "No diff tools available"
        }
    }
}

# Rollback to previous generation
def system-rollback [] {
    print "⏪ Rolling back to previous generation..."
    sudo nixos-rebuild --rollback switch
    print "✅ Rollback complete!"
}

# Show system generations
def system-generations [] {
    print "📚 System Generations:"
    sudo nix-env --list-generations --profile /nix/var/nix/profiles/system
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

