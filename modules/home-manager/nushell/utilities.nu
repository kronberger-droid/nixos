# Utility functions for various tasks

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
    # Define your SSH connections here
    let connections = {
        datalab: "user@datalab.example.com",
        asc4: "user@asc4.example.com",
        asc5: "user@asc5.example.com"
    }

    # Check if the host exists in our connections
    if ($host in $connections) {
        let ssh_target = ($connections | get $host)
        print $"Connecting to ($host) \(($ssh_target)\)..."
        if $host == datalab {
            ssh cluster.datalab.tuwien.ac.at -l martin.kronberger
        } else if $host == "asc4" {
            ^ssh sumo_mk@vsc4.vsc.ac.at
        } else if $host == "asc5" {
            ^ssh sumo_mk@vsc5.vsc.ac.at
        } 
    } else {
        print $"Error: Unknown host '($host)'"
        print "Available hosts:"
        $connections | columns | each { |h| print $"  - ($h)" }
    }
}

# QuickEMU VM management
def emu [config?: string] {
    let emulation_dir = ($env.HOME | path join "Emulation")
    let windows_dir = ($emulation_dir | path join "windows-11")

    # Check if windows-11 directory exists
    if not ($windows_dir | path exists) {
        print $"Error: QuickEMU windows-11 not initialized. Expected directory: ($windows_dir)"
        print "Run 'quickget windows 11' in the Emulation directory first."
        return
    }

    # Check if disk image exists
    let disk_path = ($windows_dir | path join "disk.qcow2")
    if not ($disk_path | path exists) {
        print $"Error: Windows 11 disk image not found at: ($disk_path)"
        print "Initialize the VM by running 'quickget windows 11' in the Emulation directory."
        return
    }

    # Determine which config to use
    let config_file = match $config {
        "default" => "windows-11-default.conf"
        "nanonis" => "windows-11-spm.conf"
        null => "windows-11-default.conf"
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

    print $"Starting Windows 11 with ($config) config..."
    cd $emulation_dir
    quickemu --vm $config_file
}
