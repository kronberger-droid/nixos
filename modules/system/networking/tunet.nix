{config, ...}: {
  # TU Wien "tunet" WiFi — WPA2 Enterprise (PEAP/MSCHAPv2)
  #
  # tunet-ca.pem is the chain TU Wien's eduroam CAT profile (IdP 1187,
  # profile 2306) ships for its RADIUS servers: GEANT TLS RSA 1 under HARICA
  # TLS RSA Root CA 2021, plus that root's cross-sign from HARICA RootCA 2015.
  # Pinned so a rogue AP with any other cert cannot harvest the MSCHAPv2
  # exchange. When TU Wien moves CA, connects fail with a cert error in the
  # journal; refresh the file from cat.eduroam.org.
  networking.networkmanager.ensureProfiles = {
    environmentFiles = [config.age.secrets.tunet-credentials.path];

    profiles.tunet = {
      connection = {
        id = "tunet";
        type = "wifi";
        autoconnect = true;
      };
      wifi = {
        ssid = "tunet";
        mode = "infrastructure";
      };
      wifi-security = {
        key-mgmt = "wpa-eap";
      };
      "802-1x" = {
        eap = "peap;";
        identity = "$TUNET_USERNAME";
        password = "$TUNET_PASSWORD";
        anonymous-identity = "anonymous@tuwien.ac.at";
        domain-suffix-match = "tuwien.ac.at";
        ca-cert = "${./tunet-ca.pem}";
        phase2-auth = "mschapv2";
      };
      ipv4.method = "auto";
      ipv6.method = "auto";
    };
  };
}
