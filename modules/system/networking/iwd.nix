{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.networking.iwdSwap;
  standalone = cfg.stage == "standalone";

  # Off unless a host opts in. Staged so each step can be tried with
  # `nixos-rebuild test` (not the boot default, so a reboot undoes it):
  #
  #   "off"         NetworkManager as today.
  #   "nm-backend"  NetworkManager still in charge, iwd underneath it for
  #                 wifi. Exercises iwd against the real networks, tunet's
  #                 PEAP included, while the profiles and nmtui stay put.
  #   "standalone"  No NetworkManager. iwd does wifi and its DHCP,
  #                 systemd-networkd does ethernet, impala replaces nmtui.
  #
  # Saved PSK networks live in NetworkManager's keyfiles and iwd cannot read
  # them, so the standalone stage carries them over once (see the importer
  # below) and keeps its own copies in /var/lib/iwd afterwards.

  # tunet as an iwd 8021x profile, the counterpart of tunet.nix's NM profile.
  # Written at boot from the same agenix env file, since the credentials sit
  # inline in the profile. ServerDomainMask is NM's domain-suffix-match.
  # Neither profile pins a CA: verify the server chain before relying on it.
  tunetProfile = pkgs.writeShellScript "iwd-tunet-profile" ''
    set -eu
    env=${config.age.secrets.tunet-credentials.path}
    # Not sourced: the password can hold anything a shell would interpret.
    user=$(${pkgs.gnused}/bin/sed -n 's/^TUNET_USERNAME=//p' "$env")
    pass=$(${pkgs.gnused}/bin/sed -n 's/^TUNET_PASSWORD=//p' "$env")
    install -d -m 700 /var/lib/iwd
    umask 077
    cat > /var/lib/iwd/tunet.8021x <<EOF
    [Security]
    EAP-Method=PEAP
    EAP-Identity=anonymous@tuwien.ac.at
    EAP-PEAP-ServerDomainMask=*.tuwien.ac.at
    EAP-PEAP-Phase2-Method=MSCHAPV2
    EAP-PEAP-Phase2-Identity=$user
    EAP-PEAP-Phase2-Password=$pass

    [Settings]
    AutoConnect=true
    EOF
  '';

  # One-time import of NetworkManager's saved PSK networks. iwd names a
  # profile after its SSID, or `=` plus the SSID in hex when the SSID holds
  # anything but alphanumerics, space and `_-`.
  importNm = pkgs.writeShellScript "iwd-import-nm" ''
    set -eu
    dir=/etc/NetworkManager/system-connections
    [ -d "$dir" ] || exit 0
    for f in "$dir"/*.nmconnection; do
      [ -e "$f" ] || continue
      ssid=$(${pkgs.gnused}/bin/sed -n 's/^ssid=//p' "$f" | head -n1)
      psk=$(${pkgs.gnused}/bin/sed -n 's/^psk=//p' "$f" | head -n1)
      [ -n "$ssid" ] && [ -n "$psk" ] || continue
      if printf %s "$ssid" | ${pkgs.gnugrep}/bin/grep -q '^[A-Za-z0-9 _-]*$'; then
        name=$ssid
      else
        name="=$(printf %s "$ssid" | ${pkgs.xxd}/bin/xxd -p | tr -d '\n')"
      fi
      out="/var/lib/iwd/$name.psk"
      [ -e "$out" ] && continue
      umask 077
      printf '[Security]\nPassphrase=%s\n' "$psk" > "$out"
      echo "imported $ssid"
    done
    touch /var/lib/iwd/.imported-from-nm
  '';
in {
  options.networking.iwdSwap.stage = lib.mkOption {
    type = lib.types.enum ["off" "nm-backend" "standalone"];
    default = "off";
    description = "How far wifi has moved from NetworkManager to iwd. See iwd.nix.";
  };

  config = lib.mkMerge [
    (lib.mkIf (cfg.stage != "off") {
      networking.wireless.iwd = {
        enable = true;
        settings = {
          # NM's `wifi.cloned-mac-address = stable`: one address per network,
          # stable across connections, never the hardware one.
          General.AddressRandomization = "network";
          Network.NameResolvingService = "systemd";
        };
      };
    })

    (lib.mkIf (cfg.stage == "nm-backend") {
      networking.networkmanager.wifi.backend = "iwd";
    })

    (lib.mkIf standalone {
      networking.networkmanager.enable = false;
      # With NetworkManager gone NixOS falls back to dhcpcd on every
      # interface, which would fight iwd and networkd over the same links;
      # nixpkgs warns that this "can lead to loss of networking".
      networking.useDHCP = lib.mkForce false;
      # iwd's own DHCP for wifi; ethernet goes to networkd below.
      networking.wireless.iwd.settings.General.EnableNetworkConfiguration = true;

      # Wired beats wifi: iwd offsets its routes by 300 by default.
      systemd.network.networks."40-wired" = {
        matchConfig.Name = "en*";
        networkConfig.DHCP = "yes";
        dhcpV4Config.RouteMetric = 100;
        ipv6AcceptRAConfig.RouteMetric = 100;
      };

      systemd.services.iwd-tunet-profile = {
        description = "Write the tunet iwd profile from agenix";
        wantedBy = ["iwd.service"];
        before = ["iwd.service"];
        after = ["agenix.service"];
        serviceConfig = {
          Type = "oneshot";
          ExecStart = tunetProfile;
        };
      };

      systemd.services.iwd-import-nm = {
        description = "Carry NetworkManager's saved PSK networks over to iwd";
        wantedBy = ["iwd.service"];
        before = ["iwd.service"];
        unitConfig.ConditionPathExists = "!/var/lib/iwd/.imported-from-nm";
        serviceConfig = {
          Type = "oneshot";
          ExecStart = importNm;
        };
      };
    })
  ];
}
