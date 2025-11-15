{ pkgs, config, ... }:
{
  services.copyparty = {
    enable = true;
    user = "copyparty";
    group = "copyparty";

    settings = {
      # Listen on all interfaces
      i = "0.0.0.0";
      # Default port
      p = 3923;
      # Disable config reload
      no-reload = true;
    };

    # Define volumes to share
    volumes = {
      "/" = {
        # Share home directory - adjust path as needed
        path = "/home/kronberger/shared";
        # Access permissions
        access = {
          # Everyone gets read-only access
          r = "*";
          # Admin user gets full access
          A = "admin";
        };
        # Volume flags
        flags = {
          # Enable uploads database
          e2d = true;
          # Scan for new files every 60 seconds
          scan = 60;
          # Enable filekeys (4 chars long)
          fk = 4;
        };
      };
    };

    # Create admin account
    accounts = {
      admin = {
        # Password file - you'll need to create this
        passwordFile = config.age.secrets.copyparty-admin-password.path;
      };
    };

    # Increase file limit for better performance
    openFilesLimit = 8192;
  };

  # Open firewall for copyparty
  networking.firewall.allowedTCPPorts = [ 3923 ];
}
