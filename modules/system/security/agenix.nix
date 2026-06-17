{
  inputs,
  username,
  ...
}: {
  # Enable SSH for agenix
  services.openssh = {
    enable = true;
    settings = {
      PasswordAuthentication = false;
      KbdInteractiveAuthentication = false;
    };
  };

  age.secrets = {
    # Hashed password for user login
    kronberger-password = {
      file = "${inputs.self}/secrets/kronberger-password.age";
      path = "/run/secrets/kronberger-password";
      mode = "0400";
      owner = "root";
    };

    # Format: PIA_USER=pXXXXXXX\nPIA_PASS=your_password
    pia-credentials = {
      file = "${inputs.self}/secrets/pia-credentials.age";
      path = "/run/secrets/pia-credentials";
      mode = "0400";
      owner = "root";
    };

    tuwien-vpn-password = {
      file = "${inputs.self}/secrets/tuwien-vpn-password.age";
      path = "/run/secrets/tuwien-vpn-password";
      mode = "0400";
      owner = "root";
    };

    tuwien-vpn-totp = {
      file = "${inputs.self}/secrets/tuwien-vpn-totp.age";
      path = "/run/secrets/tuwien-vpn-totp";
      mode = "0400";
      owner = "root";
    };

    github-token = {
      file = "${inputs.self}/secrets/github-token.age";
      path = "/run/secrets/github-token";
      mode = "0400";
      owner = username;
    };

    # Format: TUNET_USERNAME=e12202316@student.tuwien.ac.at\nTUNET_PASSWORD=your_password
    tunet-credentials = {
      file = "${inputs.self}/secrets/tunet-credentials.age";
      path = "/run/secrets/tunet-credentials";
      mode = "0400";
      owner = "root";
    };

    spotify-password = {
      file = "${inputs.self}/secrets/spotify-password.age";
      path = "/run/secrets/spotify-password";
      mode = "0400";
      owner = username;
    };

    # Single-line SFTP password, read by the sftp-mount nushell helper
    sftp-password = {
      file = "${inputs.self}/secrets/sftp-password.age";
      path = "/run/secrets/sftp-password";
      mode = "0400";
      owner = username;
    };

    # aerc mail passwords, read via *-cred-cmd (cat) in apps/aerc.nix
    aerc-gmx-password = {
      file = "${inputs.self}/secrets/aerc-gmx-password.age";
      path = "/run/secrets/aerc-gmx-password";
      mode = "0400";
      owner = username;
    };

    aerc-uptudate-password = {
      file = "${inputs.self}/secrets/aerc-uptudate-password.age";
      path = "/run/secrets/aerc-uptudate-password";
      mode = "0400";
      owner = username;
    };

  };
}
