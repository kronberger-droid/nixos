{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.services.tuwien-vpn;
in
{
  options.services.tuwien-vpn = {
    enable = mkEnableOption "TU Wien OpenConnect VPN";

    username = mkOption {
      type = types.str;
      default = "e12202316@student.tuwien.ac.at";
      description = "TU Wien VPN username";
    };

    authGroup = mkOption {
      type = types.str;
      default = "1_TU_getunnelt";
      description = "TU Wien VPN auth group";
    };

    server = mkOption {
      type = types.str;
      default = "vpn.tuwien.ac.at";
      description = "TU Wien VPN server";
    };

    passwordFile = mkOption {
      type = types.path;
      description = "Path to file containing VPN password";
    };
  };

  config = mkIf cfg.enable {
    # Install OpenConnect
    environment.systemPackages = with pkgs; [
      openconnect
    ];

    # Create systemd service for TU Wien VPN
    systemd.services.openconnect-tuwien = {
      description = "TU Wien OpenConnect VPN";
      after = [ "network-online.target" ];
      wants = [ "network-online.target" ];

      serviceConfig = {
        Type = "simple";
        ExecStart = ''
          ${pkgs.openconnect}/bin/openconnect \
            --user=${cfg.username} \
            --authgroup=${cfg.authGroup} \
            --passwd-on-stdin \
            --reconnect-timeout 30 \
            ${cfg.server}
        '';
        StandardInput = "file:${cfg.passwordFile}";
        Restart = "on-failure";
        RestartSec = "5s";

        # Security hardening
        PrivateTmp = true;
        NoNewPrivileges = false;
        ProtectSystem = "strict";
        ProtectHome = true;
        ReadWritePaths = [ "/etc/resolv.conf" ];

        # Network capabilities
        AmbientCapabilities = [ "CAP_NET_ADMIN" ];
        CapabilityBoundingSet = [ "CAP_NET_ADMIN" ];
      };
    };

    # Create wrapper script for easy control
    environment.etc."tuwien-vpn/tuwien-vpn-control.sh" = {
      text = ''
        #!/usr/bin/env bash

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
      '';
      mode = "0755";
    };

    # Add sudo rules for VPN control
    security.sudo-rs.extraRules = [
      {
        users = [ "kronberger" ];
        commands = [
          {
            command = "/run/current-system/sw/bin/systemctl start openconnect-tuwien.service";
            options = [ "NOPASSWD" ];
          }
          {
            command = "/run/current-system/sw/bin/systemctl stop openconnect-tuwien.service";
            options = [ "NOPASSWD" ];
          }
          {
            command = "/run/current-system/sw/bin/systemctl restart openconnect-tuwien.service";
            options = [ "NOPASSWD" ];
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
