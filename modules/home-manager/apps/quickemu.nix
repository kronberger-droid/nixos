{
  lib,
  osConfig ? null,
  ...
}:
# The home half of services.quickemu (modules/system/services/quickemu.nix):
# the VM configs and the `emu` launcher, only where the system side is on.
lib.mkIf (osConfig.services.quickemu.enable or false) {
  home.file = {
    "Emulation/windows-10-default.conf".source = ./quickemu/windows-10-default.conf;
    "Emulation/windows-10-spm.conf".source = ./quickemu/windows-10-spm.conf;
  };

  programs.nushell.extraConfig = ''
    # QuickEMU VM management
    def emu [config?: string] {
        let emulation_dir = ("~/Emulation" | path expand)
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
}
