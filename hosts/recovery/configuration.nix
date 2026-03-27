{
  pkgs,
  lib,
  modulesPath,
  ...
}: {
  imports = [
    (modulesPath + "/installer/cd-dvd/installation-cd-graphical-base.nix")
  ];

  # ISO image settings
  image = {
    fileName = lib.mkForce "nixos-recovery.iso";
  };
  isoImage = {
    volumeID = lib.mkForce "NIXOS_RECOVERY";
    # Include the flake for reinstallation
    contents = [
      {
        source = ../..;
        target = "/nixos-config";
      }
    ];
  };

  # Use sway as the graphical environment
  programs.sway = {
    enable = true;
    wrapperFeatures.gtk = true;
    extraPackages = with pkgs; [
      foot
      dmenu
      grim
      slurp
      wl-clipboard
      brightnessctl
    ];
  };

  # Auto-login to sway for the nixos live user
  services.greetd = {
    enable = true;
    settings.default_session = {
      command = "${pkgs.sway}/bin/sway";
      user = "nixos";
    };
  };

  # Minimal sway config via environment file
  environment.etc."sway/config".text = ''
    # Minimal recovery sway config
    set $mod Mod4
    set $term foot
    set $menu dmenu_path | dmenu | xargs swaymsg exec --

    # Terminal & launcher
    bindsym $mod+Return exec $term
    bindsym $mod+d exec $menu
    bindsym $mod+Shift+q kill
    bindsym $mod+Shift+c reload
    bindsym $mod+Shift+e exec swaynag -t warning -m 'Exit sway?' -B 'Yes' 'swaymsg exit'

    # Navigation (vim-style)
    bindsym $mod+h focus left
    bindsym $mod+j focus down
    bindsym $mod+k focus up
    bindsym $mod+l focus right

    bindsym $mod+Shift+h move left
    bindsym $mod+Shift+j move down
    bindsym $mod+Shift+k move up
    bindsym $mod+Shift+l move right

    # Workspaces
    bindsym $mod+1 workspace 1
    bindsym $mod+2 workspace 2
    bindsym $mod+3 workspace 3
    bindsym $mod+4 workspace 4
    bindsym $mod+5 workspace 5
    bindsym $mod+Shift+1 move container to workspace 1
    bindsym $mod+Shift+2 move container to workspace 2
    bindsym $mod+Shift+3 move container to workspace 3
    bindsym $mod+Shift+4 move container to workspace 4
    bindsym $mod+Shift+5 move container to workspace 5

    # Layout
    bindsym $mod+b splith
    bindsym $mod+v splitv
    bindsym $mod+f fullscreen toggle
    bindsym $mod+space floating toggle
    bindsym $mod+Shift+space focus mode_toggle

    # Resize mode
    mode "resize" {
      bindsym h resize shrink width 10px
      bindsym j resize grow height 10px
      bindsym k resize shrink height 10px
      bindsym l resize grow width 10px
      bindsym Return mode "default"
      bindsym Escape mode "default"
    }
    bindsym $mod+r mode "resize"

    # Screenshots
    bindsym $mod+Shift+s exec grim -g "$(slurp)" - | wl-copy

    # Appearance
    default_border pixel 2
    gaps inner 4
    font pango:monospace 10

    # Status bar
    bar {
      position top
      status_command while date +'%Y-%m-%d %H:%M:%S'; do sleep 1; done
      colors {
        statusline #ffffff
        background #323232
      }
    }

    # Float gparted
    for_window [instance="gpartedbin"] floating enable

    # Auto-start terminal
    exec foot
  '';

  # Keyd — same as main config
  services.keyd = {
    enable = true;
    keyboards = {
      apple = {
        ids = ["05ac:020c"];
        settings = {
          main = {
            leftalt = "leftalt";
            leftmeta = "leftmeta";
            rightshift = "layer(backspace_layer)";
            rightalt = "layer(meta_layer)";
            capslock = "overload(control, esc)";
          };
          "backspace_layer" = {
            space = "backspace";
          };
          "control:C" = {
            h = "left";
            k = "up";
            j = "down";
            l = "right";
          };
          "meta_layer" = {
            "o" = "macro(compose o \")";
            "u" = "macro(compose u \")";
            "a" = "macro(compose a \")";
            "s" = "macro(compose s s)";
          };
          "shift+meta_layer" = {
            "o" = "macro(compose O \")";
            "u" = "macro(compose U \")";
            "a" = "macro(compose A \")";
          };
        };
      };
      default = {
        ids = ["*"];
        settings = {
          main = {
            leftalt = "leftmeta";
            leftmeta = "leftalt";
            rightshift = "layer(backspace_layer)";
            rightalt = "layer(meta_layer)";
            capslock = "overload(control, esc)";
          };
          "backspace_layer" = {
            space = "backspace";
          };
          "control:C" = {
            h = "left";
            k = "up";
            j = "down";
            l = "right";
          };
          "meta_layer" = {
            "o" = "macro(compose o \")";
            "u" = "macro(compose u \")";
            "a" = "macro(compose a \")";
            "s" = "macro(compose s s)";
          };
          "shift+meta_layer" = {
            "o" = "macro(compose O \")";
            "u" = "macro(compose U \")";
            "a" = "macro(compose A \")";
          };
        };
      };
    };
  };

  # Shell — nushell + helix as default
  programs.bash.interactiveShellInit = ''
    if [[ $(${pkgs.procps}/bin/ps --no-header --pid=$PPID --format=comm) != "nu" && -z ''${BASH_EXECUTION_STRING} ]]; then
      shopt -s expand_aliases
      exec ${pkgs.nushell}/bin/nu
    fi
  '';

  environment.variables.EDITOR = "hx";

  # Packages — disk tools, networking, recovery essentials
  environment.systemPackages = with pkgs; [
    # Editor & shell
    helix
    nushell

    # Disk management (GUI)
    gparted

    # Disk management (CLI)
    parted
    gptfdisk # gdisk, sgdisk, cgdisk
    dosfstools
    e2fsprogs
    btrfs-progs
    xfsprogs
    ntfs3g
    lvm2
    mdadm
    cryptsetup

    # Disk imaging & recovery
    ddrescue
    testdisk # includes photorec

    # Disk health
    smartmontools
    hdparm

    # Filesystem tools
    fuse3
    squashfsTools

    # Networking — diagnostics & transfer
    wget
    curl
    git
    rsync
    openssh
    nmap
    tcpdump
    iperf3
    dig
    whois
    traceroute
    ethtool
    iw # wireless config
    wireguard-tools

    # System info & monitoring
    pciutils
    usbutils
    lshw
    htop
    btop
    lsof
    strace

    # NixOS installation
    nixos-install-tools

    # Clipboard for sway
    wl-clipboard
  ];

  # Enable networking for downloads during install
  # (wireless.enable is already set by the base installer module)
  networking.networkmanager.enable = true;

  # Hardware support — broad driver coverage for recovery
  hardware.enableAllFirmware = true;

  nixpkgs.config.allowUnfree = true;

  nix.settings.experimental-features = ["nix-command" "flakes"];
}
