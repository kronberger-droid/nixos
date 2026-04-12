{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.services.tuwien-vpn;
in {
  options.services.tuwien-vpn = {
    enable = lib.mkEnableOption "TU Wien OpenConnect VPN";

    username = lib.mkOption {
      type = lib.types.str;
      description = "TU Wien VPN username";
    };

    authGroup = lib.mkOption {
      type = lib.types.str;
      default = "1_TU_getunnelt";
      description = "TU Wien VPN auth group";
    };

    server = lib.mkOption {
      type = lib.types.str;
      default = "vpn.tuwien.ac.at";
      description = "TU Wien VPN server";
    };

    passwordFile = lib.mkOption {
      type = lib.types.path;
      description = "Path to file containing VPN password";
    };

    totpSecretFile = lib.mkOption {
      type = lib.types.path;
      description = "Path to file containing the TOTP secret (base32 encoded)";
    };
  };

  config = lib.mkIf cfg.enable {
    # Create systemd service for TU Wien VPN
    systemd.services.openconnect-tuwien = let
      connectScript = pkgs.writeShellScript "tuwien-vpn-connect" ''
        PASSWORD=$(cat "${cfg.passwordFile}")
        TOTP=$(${pkgs.oath-toolkit}/bin/oathtool --totp --base32 "$(cat "${cfg.totpSecretFile}")")
        printf '%s\n%s\n' "$PASSWORD" "$TOTP" | \
          ${pkgs.openconnect}/bin/openconnect \
            --user=${cfg.username} \
            --authgroup=${cfg.authGroup} \
            --useragent "AnyConnect OpenConnect" \
            --no-external-auth \
            --passwd-on-stdin \
            --reconnect-timeout 30 \
            ${cfg.server}
      '';
    in {
      description = "TU Wien OpenConnect VPN";
      after = ["network-online.target"];
      wants = ["network-online.target"];

      serviceConfig = {
        Type = "simple";
        ExecStart = connectScript;
        Restart = "on-failure";
        RestartSec = "5s";

        # Security hardening
        PrivateTmp = true;
        ProtectHome = true;

        # Network capabilities
        AmbientCapabilities = ["CAP_NET_ADMIN"];
        CapabilityBoundingSet = ["CAP_NET_ADMIN"];
      };
    };

    environment.systemPackages = [
      pkgs.openconnect
      (pkgs.writeShellScriptBin "tuwien-vpn" ''
        case "$1" in
          start)
            ${pkgs.systemd}/bin/systemctl start openconnect-tuwien.service
            ;;
          stop)
            ${pkgs.systemd}/bin/systemctl stop openconnect-tuwien.service
            ;;
          status)
            ${pkgs.systemd}/bin/systemctl is-active openconnect-tuwien.service >/dev/null 2>&1
            ;;
          *)
            echo "Usage: $0 {start|stop|status}"
            exit 1
            ;;
        esac
      '')
    ];

    # Add sudo rules for VPN control
    security.sudo-rs.extraRules = [
      {
        users = ["kronberger"];
        commands = [
          {
            command = "/run/current-system/sw/bin/systemctl start openconnect-tuwien.service";
            options = ["NOPASSWD"];
          }
          {
            command = "/run/current-system/sw/bin/systemctl stop openconnect-tuwien.service";
            options = ["NOPASSWD"];
          }
          {
            command = "/run/current-system/sw/bin/systemctl restart openconnect-tuwien.service";
            options = ["NOPASSWD"];
          }
        ];
      }
    ];

    # Add polkit rule for GUI/waybar control
    security.polkit.extraConfig = ''
      polkit.addRule(function(action, subject) {
          if ((action.id == "org.freedesktop.systemd1.manage-units" &&
               action.lookup("unit") == "openconnect-tuwien.service") &&
              subject.user == "kronberger") {
              return polkit.Result.YES;
          }
      });
    '';
  };
}
