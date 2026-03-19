{inputs, ...}: {
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

    arrabbiata-config = {
      file = "${inputs.self}/secrets/arrabbiata-config.age";
      path = "/run/secrets/arrabbiata-config";
      mode = "0400";
      owner = "kronberger";
    };

    github-token = {
      file = "${inputs.self}/secrets/github-token.age";
      path = "/run/secrets/github-token";
      mode = "0400";
      owner = "kronberger";
    };

    # Format: TUNET_USERNAME=e12202316@student.tuwien.ac.at\nTUNET_PASSWORD=your_password
    tunet-credentials = {
      file = "${inputs.self}/secrets/tunet-credentials.age";
      path = "/run/secrets/tunet-credentials";
      mode = "0400";
      owner = "root";
    };
  };
}
