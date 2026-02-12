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

    secrets.openclaw-anthropic-api-key = {
      file = "${inputs.self}/secrets/openclaw-anthropic-api-key.age";
      path = "/run/secrets/openclaw-anthropic-api-key";
      mode = "0400";
      owner = "kronberger";
    };
  };
}
