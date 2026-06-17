{
  inputs,
  username,
  lib,
  ...
}: let
  # Every secret has the same shape: an age file in ./secrets, decrypted to
  # /run/secrets/<name> with mode 0400. Only the owner varies (root vs the
  # primary user), so list the names and let mkSecret fill in the rest.
  mkSecret = owner: name: {
    file = "${inputs.self}/secrets/${name}.age";
    path = "/run/secrets/${name}";
    mode = "0400";
    inherit owner;
  };

  # Decrypted for root (consumed by system services / login).
  rootSecrets = [
    "kronberger-password" # hashed password for user login
    "pia-credentials" # PIA_USER=pXXXXXXX\nPIA_PASS=your_password
    "tuwien-vpn-password"
    "tuwien-vpn-totp"
    "tunet-credentials" # TUNET_USERNAME=e12202316@student.tuwien.ac.at\nTUNET_PASSWORD=your_password
  ];

  # Decrypted for the primary user (read directly from their session/tools).
  userSecrets = [
    "github-token"
    "spotify-password"
    "sftp-password" # single-line SFTP password, read by the sftp-mount nushell helper
    "aerc-gmx-password" # aerc mail passwords, read via *-cred-cmd (cat) in apps/aerc.nix
    "aerc-uptudate-password"
  ];
in {
  # Enable SSH for agenix
  services.openssh = {
    enable = true;
    settings = {
      PasswordAuthentication = false;
      KbdInteractiveAuthentication = false;
    };
  };

  age.secrets =
    lib.genAttrs rootSecrets (mkSecret "root")
    // lib.genAttrs userSecrets (mkSecret username);
}
