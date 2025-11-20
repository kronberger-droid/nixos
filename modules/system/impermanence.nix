{ config, lib, inputs, ... }:

{
  imports = [
    inputs.impermanence.nixosModules.impermanence
  ];

  # Ephemeral root filesystem - everything is wiped on reboot except persisted paths
  environment.persistence."/nix/persist" = {
    hideMounts = true;

    directories = [
      # System state
      "/var/lib/nixos"
      "/var/lib/systemd"
      "/var/lib/bluetooth"
      "/var/lib/NetworkManager"
      "/var/db/sudo/lectured"

      # Logs and cache
      "/var/log"
      "/var/cache"

      # Network and DNS
      "/etc/NetworkManager/system-connections"

      # Virtualization
      "/var/lib/libvirt"

      # Service state
      "/var/lib/fail2ban"
    ];

    files = [
      # Machine ID
      "/etc/machine-id"

      # SSH host keys
      "/etc/ssh/ssh_host_ed25519_key"
      "/etc/ssh/ssh_host_ed25519_key.pub"
      "/etc/ssh/ssh_host_rsa_key"
      "/etc/ssh/ssh_host_rsa_key.pub"
    ];

    users.kronberger = {
      directories = [
        # User configuration
        ".config"
        ".local/share"
        ".local/state"

        # Cache directories
        ".cache"

        # Development
        "projects"
        "Documents"
        "Downloads"
        "Pictures"
        "Videos"
        "Music"

        # SSH keys
        ".ssh"

        # Application specific
        ".mozilla"
        ".thunderbird"
        { directory = ".gnupg"; mode = "0700"; }
        { directory = ".password-store"; mode = "0700"; }

        # Trash (used by rip command)
        ".local/share/Trash"
      ];

      files = [
        # Shell history
        ".bash_history"
        ".local/share/nushell/history.txt"
      ];
    };
  };

  # Persist root user SSH keys for agenix
  environment.persistence."/nix/persist".users.root = {
    home = "/root";
    directories = [
      ".ssh"
    ];
  };
}
