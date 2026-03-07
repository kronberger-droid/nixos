{
  pkgs,
  config,
  inputs,
  lib,
  ...
}: let
  cfg = config.services.pia;

  piaCert = pkgs.fetchurl {
    url = "https://raw.githubusercontent.com/pia-foss/manual-connections/master/ca.rsa.4096.crt";
    sha256 = "sha256-Mumx0UM+qXYU8qFMbjWOP1fAVwzJ9rLugSaZumlsZqs=";
  };
in {
  imports = [
    inputs.nix-pia-vpn.nixosModules.default
  ];

  options.services.pia = {
    enable = lib.mkEnableOption "PIA VPN (WireGuard)";

    environmentFile = lib.mkOption {
      type = lib.types.path;
      description = "Path to environment file containing PIA_USER and PIA_PASS";
    };
  };

  config = lib.mkIf cfg.enable {
    services.pia-vpn = {
      enable = true;
      certificateFile = piaCert;
      environmentFile = cfg.environmentFile;
      region = "";
      interface = "pia0";
    };

    # Don't auto-start on boot (matching previous behavior)
    systemd.services.pia-vpn.wantedBy = lib.mkForce [];

    # Allow kronberger to start/stop PIA via sudo
    security.sudo-rs.extraRules = [
      {
        users = ["kronberger"];
        commands = [
          {
            command = "/run/current-system/sw/bin/systemctl start pia-vpn.service";
            options = ["NOPASSWD" "SETENV"];
          }
          {
            command = "/run/current-system/sw/bin/systemctl stop pia-vpn.service";
            options = ["NOPASSWD" "SETENV"];
          }
          {
            command = "/run/current-system/sw/bin/systemctl restart pia-vpn.service";
            options = ["NOPASSWD" "SETENV"];
          }
        ];
      }
    ];
  };
}
