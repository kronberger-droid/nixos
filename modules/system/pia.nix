{
  pkgs,
  config,
  inputs,
  lib,
  ...
}: let
  cfg = config.services.pia;

  # Create a wrapper script generator that works for any region
  makeOpenvpnWrapper = region:
    pkgs.writeShellScript "openvpn-${region}-wrapper" ''
      # Find the most recent config using glob pattern (sorted by modification time)
      WRAPPER_CONFIG=$(${pkgs.coreutils}/bin/ls -t /nix/store/*-openvpn-config-${region} 2>/dev/null | ${pkgs.coreutils}/bin/head -1)

      if [ -z "$WRAPPER_CONFIG" ] || [ ! -f "$WRAPPER_CONFIG" ]; then
        echo "ERROR: Could not find openvpn-config-${region} in /nix/store" >&2
        exit 1
      fi

      ACTUAL_CONFIG=$(${pkgs.gnugrep}/bin/grep -oP 'config \K.*' "$WRAPPER_CONFIG" 2>/dev/null | ${pkgs.coreutils}/bin/head -1)

      if [ -z "$ACTUAL_CONFIG" ] || [ ! -f "$ACTUAL_CONFIG" ]; then
        echo "ERROR: Could not find PIA ${region} config at $ACTUAL_CONFIG" >&2
        exit 1
      fi

      # Create filtered config in /tmp without CRL section
      FILTERED="/tmp/${region}-filtered.ovpn"
      ${pkgs.gnused}/bin/sed '/<crl-verify>/,/<\/crl-verify>/d' "$ACTUAL_CONFIG" > "$FILTERED"

      # Run OpenVPN with filtered config
      exec ${pkgs.openvpn}/sbin/openvpn \
        --suppress-timestamps \
        --errors-to-stderr \
        --script-security 2 \
        --config "$FILTERED" \
        --auth-nocache \
        --auth-user-pass ${config.age.secrets.pia-credentials.path}
    '';

  # List of commonly used regions
  piaRegions = [
    "austria"
    "australia"
    "au-melbourne"
    "au-sydney"
    "au-perth"
    "belgium"
    "brazil"
    "canada"
    "ca-toronto"
    "ca-montreal"
    "ca-vancouver"
    "denmark"
    "finland"
    "france"
    "germany"
    "italy"
    "japan"
    "netherlands"
    "norway"
    "poland"
    "spain"
    "sweden"
    "switzerland"
    "uk-london"
    "uk-manchester"
    "uk-southampton"
    "us-east"
    "us-west"
    "us-chicago"
    "us-texas"
    "us-california"
  ];

  # Generate service overrides for all regions
  serviceOverrides =
    lib.genAttrs
    (map (r: "openvpn-${r}") piaRegions)
    (
      serviceName: let
        region = lib.removePrefix "openvpn-" serviceName;
      in {
        serviceConfig.ExecStart = lib.mkForce "@${makeOpenvpnWrapper region} openvpn";
        wantedBy = lib.mkForce []; # Don't auto-start on boot
      }
    );
in {
  imports = [
    inputs.pia.nixosModules."x86_64-linux".default
  ];

  config = lib.mkIf cfg.enable {
    # Workaround for PIA OpenVPN CRL certificate issue
    # See: https://github.com/Fuwn/pia.nix/issues/2
    # The PIA configs include a crl-verify section with malformed CRL that OpenSSL 3.x rejects
    systemd.services = serviceOverrides;

    # Add sudo rules for PIA VPN control (for terminal use)
    security.sudo-rs.extraRules = [
      {
        users = ["kronberger"];
        commands = [
          {
            command = "/run/current-system/sw/bin/pia";
            options = ["NOPASSWD" "SETENV"];
          }
        ];
      }
    ];

    # Add polkit rule for PIA VPN control (for GUI/systemd services)
    security.polkit.extraConfig = ''
      polkit.addRule(function(action, subject) {
          if (action.id == "org.freedesktop.policykit.exec" &&
              action.lookup("program") == "/run/current-system/sw/bin/pia" &&
              subject.user == "kronberger") {
              return polkit.Result.YES;
          }
      });
    '';
  };
}
