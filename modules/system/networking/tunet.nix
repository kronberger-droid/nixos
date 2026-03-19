{config, ...}: {
  # TU Wien "tunet" WiFi — WPA2 Enterprise (PEAP/MSCHAPv2)
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
        phase2-auth = "mschapv2";
      };
      ipv4.method = "auto";
      ipv6.method = "auto";
    };
  };
}
