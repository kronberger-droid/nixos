{ inputs, ... }:
{
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

    secrets.copyparty-admin-password = {
      file = "${inputs.self}/secrets/copyparty-admin-password.age";
      path = "/run/secrets/copyparty-admin-password";
      mode = "0444";
      owner = "root";
    };
  };
}
