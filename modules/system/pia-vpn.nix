{
  config,
  lib,
  pkgs,
  ...
}:
with lib; let
  cfg = config.services.pia-vpn;
in {
  options.services.pia-vpn = {
    enable = mkEnableOption "Private Internet Access VPN with NetworkManager integration";

    region = mkOption {
      type = types.str;
      default = "netherlands";
      description = "PIA server region";
    };
  };

  config = mkIf cfg.enable {
    # Install required packages and create VPN management scripts
    environment = {
      systemPackages = with pkgs; [
        networkmanager-openvpn
        gnome-keyring
        libsecret
        # PIA-specific tools
        curl
        jq
      ];

      etc = {
        "pia-vpn/setup-pia.sh" = {
          text = ''
            #!/usr/bin/env bash

            PIA_CONFIG_DIR="/tmp/pia-configs"
            REGION="${cfg.region}"

            echo "Setting up PIA VPN with GNOME Keyring integration..."

            # Download PIA OpenVPN configs
            echo "Downloading PIA OpenVPN configurations..."
            mkdir -p "$PIA_CONFIG_DIR"
            cd "$PIA_CONFIG_DIR"

            # Download and extract PIA configs
            curl -o pia-configs.zip "https://www.privateinternetaccess.com/openvpn/openvpn.zip"
            unzip -o pia-configs.zip

            # Find the config file for the specified region
            CONFIG_FILE=$(find . -name "*$REGION*" | head -1)

            if [ -z "$CONFIG_FILE" ]; then
              echo "Region '$REGION' not found. Available regions:"
              ls *.ovpn | sed 's/.ovpn$//' | sort
              exit 1
            fi

            echo "Found config: $CONFIG_FILE"

            # Get credentials for setup
            echo "Please enter your PIA credentials..."
            read -p "Username: " USERNAME
            read -s -p "Password: " PASSWORD
            echo

            # Print manual keyring setup instructions
            echo ""
            echo "=== Manual GNOME Keyring Setup ==="
            echo "After this setup completes, store your password in the keyring with:"
            echo "secret-tool store --label=\"PIA VPN Password\" service pia-vpn username \"$USERNAME\""
            echo "(You'll be prompted for your password)"
            echo ""

            # Import the VPN connection to NetworkManager
            echo "Importing VPN connection to NetworkManager..."
            nmcli connection import type openvpn file "$CONFIG_FILE"

            # Get the connection name
            CONNECTION_NAME=$(basename "$CONFIG_FILE" .ovpn)

            # Configure the connection to use keyring
            nmcli connection modify "$CONNECTION_NAME" vpn.data username="$USERNAME"
            nmcli connection modify "$CONNECTION_NAME" vpn.secrets password-flags=1

            echo "PIA VPN setup complete!"
            echo "Connection name: $CONNECTION_NAME"
            echo "You can now connect using: nmcli connection up '$CONNECTION_NAME'"

            # Clean up
            rm -rf "$PIA_CONFIG_DIR"
          '';
          mode = "0755";
        };

        "pia-vpn/pia-connect.sh" = {
          text = ''
            #!/usr/bin/env bash

            REGION="${cfg.region}"
            CONNECTION_NAME=$(nmcli connection show | grep -i "$REGION" | grep vpn | awk '{print $1}' | head -1)

            if [ -z "$CONNECTION_NAME" ]; then
              echo "No PIA connection found for region '$REGION'. Run setup-pia.sh first."
              exit 1
            fi

            nmcli connection up "$CONNECTION_NAME"
          '';
          mode = "0755";
        };

        "pia-vpn/pia-disconnect.sh" = {
          text = ''
            #!/usr/bin/env bash

            REGION="${cfg.region}"
            CONNECTION_NAME=$(nmcli connection show --active | grep -i "$REGION" | grep vpn | awk '{print $1}' | head -1)

            if [ -n "$CONNECTION_NAME" ]; then
              nmcli connection down "$CONNECTION_NAME"
            else
              echo "No active PIA connection found."
            fi
          '';
          mode = "0755";
        };

        "pia-vpn/pia-status.sh" = {
          text = ''
            #!/usr/bin/env bash

            REGION="${cfg.region}"
            CONNECTION_NAME=$(nmcli connection show --active | grep -i "$REGION" | grep vpn | awk '{print $1}' | head -1)

            if [ -n "$CONNECTION_NAME" ]; then
              echo "connected"
            else
              echo "disconnected"
            fi
          '';
          mode = "0755";
        };

        "pia-vpn/pia-toggle.sh" = {
          text = ''
            #!/usr/bin/env bash

            STATUS=$(/etc/pia-vpn/pia-status.sh)

            if [ "$STATUS" = "connected" ]; then
              /etc/pia-vpn/pia-disconnect.sh
              notify-send "VPN" "Disconnected from PIA" -i network-vpn-disconnected
            else
              /etc/pia-vpn/pia-connect.sh
              if [ $? -eq 0 ]; then
                notify-send "VPN" "Connected to PIA" -i network-vpn
              else
                notify-send "VPN" "Failed to connect to PIA" -i dialog-error
              fi
            fi
          '';
          mode = "0755";
        };
      };
    };

    # Enable NetworkManager OpenVPN plugin
    networking.networkmanager.plugins = with pkgs; [
      networkmanager-openvpn
    ];

    # Add sudo rules for VPN control without passwords
    security.sudo.extraRules = [
      {
        users = ["kronberger"];
        commands = [
          {
            command = "/etc/pia-vpn/pia-connect.sh";
            options = ["NOPASSWD"];
          }
          {
            command = "/etc/pia-vpn/pia-disconnect.sh";
            options = ["NOPASSWD"];
          }
          {
            command = "/etc/pia-vpn/pia-toggle.sh";
            options = ["NOPASSWD"];
          }
        ];
      }
    ];

    # Ensure GNOME keyring is available at login
    services.gnome.gnome-keyring.enable = true;

    # Enable secret service for applications
    programs.seahorse.enable = true;
  };
}
