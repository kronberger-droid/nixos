{inputs, ...}: {
  # Enable SSH for agenix
  services.openssh = {
    enable = true;
    settings = {
      PasswordAuthentication = false;
      KbdInteractiveAuthentication = false;
    };
  };

  age = {
    # Format: PIA_USER=pXXXXXXX\nPIA_PASS=your_password
    secrets.pia-credentials = {
      file = "${inputs.self}/secrets/pia-credentials.age";
      path = "/run/secrets/pia-credentials";
      mode = "0400";
      owner = "root";
    };

    secrets.tuwien-vpn-password = {
      file = "${inputs.self}/secrets/tuwien-vpn-password.age";
      path = "/run/secrets/tuwien-vpn-password";
      mode = "0400";
      owner = "root";
    };

    secrets.arrabbiata-config = {
      file = "${inputs.self}/secrets/arrabbiata-config.age";
      path = "/run/secrets/arrabbiata-config";
      mode = "0400";
      owner = "kronberger";
    };

    secrets.github-token = {
      file = "${inputs.self}/secrets/github-token.age";
      path = "/run/secrets/github-token";
      mode = "0400";
      owner = "kronberger";
    };
  };
}
