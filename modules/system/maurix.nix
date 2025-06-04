{ config, pkgs, lib, ... }:

let
  HS_SECRET = "6ab83fc8cb65d33830991f1d19bab33b2a8ebc60871ea6db866e7ccc92d29df6";
  AS_TOKEN  = "5e1bda3abeea06dcc897ab162f2db09ee3a429b03492cafa99b58ff78435e771";
in
{
  environment.systemPackages = with pkgs; [
    iamb
    python3Packages.mautrix-whatsapp
  ];

  users.users.whatsapp-bridge = {
    isSystemUser = true;
    home = "/var/lib/mautrix-whatsapp";
    createHome = true;
    description = "mautrix-whatsapp bridge user";
  };

  systemd.tmpfiles.rules = lib.mkForce ([
    "d /var/lib/mautrix-whatsapp 0750 whatsapp-bridge whatsapp-bridge - -"
    ''
f /var/lib/mautrix-whatsapp/config.yaml 0600 whatsapp-bridge whatsapp-bridge - - homeserver: "http://127.0.0.1:8008"
login:
  user_id: "@whatsapp-bridge:localhost"
  password: "bridge-user-password"
appservice:
  id: "whatsapp"
  hs_token: "${HS_SECRET}"
  url: "http://127.0.0.1:3000"
database:
  type: sqlite
  sqlite_file: "/var/lib/mautrix-whatsapp/bridge.db"
bind_address: "127.0.0.1"
listen_port: 3000
logging:
  level: "info"
  file: "/var/lib/mautrix-whatsapp/bridge.log"
''
    ''
f /etc/matrix-synapse/appservices/mautrix-whatsapp-registration.yaml 0640 root root - - id: "whatsapp"
url: "http://127.0.0.1:3000"
as_token: "${AS_TOKEN}"
hs_token: "${HS_SECRET}"
namespaces:
  users:
    - exclusive: true
      regex: "@_whatsapp_.*:localhost"
  aliases:
    - exclusive: false
      regex: "#_whatsapp_.*:localhost"
  rooms:
    - exclusive: false
      regex: "#_whatsapp_.*:localhost"
rate_limited: false
''
  ]);

  systemd.services.mautrix-whatsapp = {
    description = "mautrix-whatsapp bridge";
    wants = [ "network-online.target" ];
    after = [ "network-online.target" ];
    serviceConfig = {
      User = "whatsapp-bridge";
      Group = "whatsapp-bridge";
      WorkingDirectory = "/var/lib/mautrix-whatsapp";
      ExecStart = ''
        ${pkgs.python3Packages.mautrix-whatsapp}/bin/mautrix-whatsapp \
          --config /var/lib/mautrix-whatsapp/config.yaml \
          --registration-file /etc/matrix-synapse/appservices/mautrix-whatsapp-registration.yaml
      '';
      Restart = "on-failure";
      RestartSec = "5s";
    };
    preStart = ''
      install -d -m 750 /var/lib/mautrix-whatsapp
      chown -R whatsapp-bridge:whatsapp-bridge /var/lib/mautrix-whatsapp
    '';
    wantedBy = [ "multi-user.target" ];
  };
}
